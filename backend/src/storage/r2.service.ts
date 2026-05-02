import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
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

  constructor(config: ConfigService) {
    const accountId = config.getOrThrow<string>('R2_ACCOUNT_ID');
    this.bucket = config.getOrThrow<string>('R2_BUCKET');
    this.publicBaseUrl = config.getOrThrow<string>('R2_PUBLIC_BASE_URL');
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
}
