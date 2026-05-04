import { DeleteObjectCommand, ListObjectsV2Command, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';

type MediaKind =
  | 'audio'
  | 'audio/library'
  | 'audio/meditation'
  | 'video'
  | 'video/dharma'
  | 'images/audio'
  | 'images/video'
  | 'images/banner'
  | 'images/quote'
  | 'images/news'
  | 'images/scripture'
  | 'images/meditation';

@Injectable()
export class R2Service {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;
  private readonly accountId: string;
  private readonly cloudflareApiToken?: string;
  private readonly storageLimitBytes: number;
  private readonly bandwidth30dLimitBytes: number;
  private readonly requests30dLimit: number;

  constructor(config: ConfigService) {
    const accountId = config.getOrThrow<string>('R2_ACCOUNT_ID');
    this.accountId = accountId;
    this.bucket = config.getOrThrow<string>('R2_BUCKET');
    this.publicBaseUrl = config.getOrThrow<string>('R2_PUBLIC_BASE_URL');
    this.cloudflareApiToken = config.get<string>('CLOUDFLARE_API_TOKEN') || config.get<string>('R2_API_TOKEN');
    this.storageLimitBytes = parseNumericLimit(config.get<string>('R2_STORAGE_LIMIT_BYTES'), 10 * 1024 ** 3);
    this.bandwidth30dLimitBytes = parseNumericLimit(config.get<string>('R2_BANDWIDTH_30D_LIMIT_BYTES'), 100 * 1024 ** 3);
    this.requests30dLimit = parseNumericLimit(config.get<string>('R2_REQUESTS_30D_LIMIT'), 10_000_000);
    this.client = new S3Client({
      region: 'auto',
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: config.getOrThrow<string>('R2_ACCESS_KEY_ID'),
        secretAccessKey: config.getOrThrow<string>('R2_SECRET_ACCESS_KEY'),
      },
    });
  }

  async createPresignedPutUrl(kind: MediaKind, contentType: string) {
    const extension = contentType.includes('mpeg') ? 'mp3' : contentType.includes('mp4') ? 'mp4' : 'webp';
    const key = `${kind}/${randomUUID()}.${extension}`;
    const command = new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType });
    return {
      key,
      uploadUrl: await getSignedUrl(this.client, command, { expiresIn: 60 * 10 }),
      publicUrl: `${this.publicBaseUrl}/${key}`,
    };
  }

  keyFromPublicUrl(url?: string | null) {
    if (!url) return null;
    const base = this.publicBaseUrl.replace(/\/$/, '');
    if (!url.startsWith(`${base}/`)) return null;
    const key = decodeURIComponent(url.slice(base.length + 1).split('?')[0]);
    return key || null;
  }

  async deletePublicUrl(url?: string | null) {
    const key = this.keyFromPublicUrl(url);
    if (!key) return false;
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
    return true;
  }

  async deletePublicUrls(urls: Array<string | null | undefined>) {
    const keys = [...new Set(urls.map((url) => this.keyFromPublicUrl(url)).filter((key): key is string => Boolean(key)))];
    await Promise.all(keys.map((key) => this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }))));
    return { deleted: keys.length };
  }

  async usage() {
    let continuationToken: string | undefined;
    let objectCount = 0;
    let storageBytes = 0;
    do {
      const response = await this.client.send(new ListObjectsV2Command({
        Bucket: this.bucket,
        ContinuationToken: continuationToken,
      }));
      for (const item of response.Contents ?? []) {
        objectCount += 1;
        storageBytes += item.Size ?? 0;
      }
      continuationToken = response.IsTruncated ? response.NextContinuationToken : undefined;
    } while (continuationToken);

    return {
      bucket: this.bucket,
      objectCount,
      storageBytes,
      limits: {
        storageBytes: this.storageLimitBytes,
        bandwidth30dBytes: this.bandwidth30dLimitBytes,
        requests30d: this.requests30dLimit,
      },
      bandwidth: await this.cloudflareBandwidth(),
    };
  }

  private async cloudflareBandwidth() {
    if (!this.cloudflareApiToken) {
      return { available: false, reason: 'missing CLOUDFLARE_API_TOKEN', requests: null, bytes: null };
    }
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const until = new Date().toISOString();
    const query = `
      query R2Usage($accountTag: string!, $since: Time!, $until: Time!) {
        viewer {
          accounts(filter: { accountTag: $accountTag }) {
            r2OperationsAdaptiveGroups(limit: 1000, filter: { datetime_geq: $since, datetime_leq: $until }) {
              sum { requests responseBytes }
            }
          }
        }
      }
    `;
    try {
      const response = await fetch('https://api.cloudflare.com/client/v4/graphql', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.cloudflareApiToken}`,
        },
        body: JSON.stringify({ query, variables: { accountTag: this.accountId, since, until } }),
      });
      const payload = await response.json() as {
        data?: { viewer?: { accounts?: Array<{ r2OperationsAdaptiveGroups?: Array<{ sum?: { requests?: number; responseBytes?: number } }> }> } };
        errors?: unknown[];
      };
      if (!response.ok || payload.errors?.length) {
        return { available: false, reason: 'cloudflare metrics unavailable', requests: null, bytes: null };
      }
      const groups = payload.data?.viewer?.accounts?.[0]?.r2OperationsAdaptiveGroups ?? [];
      return {
        available: true,
        reason: null,
        requests: groups.reduce((sum, group) => sum + (group.sum?.requests ?? 0), 0),
        bytes: groups.reduce((sum, group) => sum + (group.sum?.responseBytes ?? 0), 0),
      };
    } catch {
      return { available: false, reason: 'cloudflare metrics unavailable', requests: null, bytes: null };
    }
  }
}

function parseNumericLimit(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}
