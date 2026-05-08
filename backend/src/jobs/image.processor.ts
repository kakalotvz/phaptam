import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import sharp from 'sharp';
import { R2Service } from '../storage/r2.service';

@Processor('image')
export class ImageProcessor extends WorkerHost {
  constructor(private readonly r2: R2Service) {
    super();
  }

  async process(job: Job<OptimizeImageJob>) {
    if (job.name !== 'optimize') return;
    const publicUrl = job.data.publicUrl?.trim();
    const sourceKey = this.r2.keyFromPublicUrl(publicUrl);
    if (!publicUrl || !sourceKey) throw new Error('Image optimizer only accepts images from the configured R2 public base URL');

    const input = await downloadImage(publicUrl);
    const quality = clampNumber(job.data.quality, 70, 85, 82);
    const maxEdge = clampNumber(job.data.maxEdge, 320, 2400, 1600);
    const output = await sharp(input)
      .rotate()
      .resize({ width: maxEdge, height: maxEdge, fit: 'inside', withoutEnlargement: true })
      .webp({ quality })
      .toBuffer();

    const optimizedKey = optimizedImageKey(sourceKey);
    const optimizedUrl = await this.r2.putObject(optimizedKey, output, 'image/webp');
    if (job.data.deleteOriginal === true) await this.r2.deletePublicUrl(publicUrl);
    return { ok: true, publicUrl: optimizedUrl, key: optimizedKey, sizeBytes: output.length };
  }
}

type OptimizeImageJob = {
  publicUrl?: string;
  maxEdge?: number;
  quality?: number;
  deleteOriginal?: boolean;
};

async function downloadImage(url: string) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error(`Image download failed: ${response.status}`);
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.startsWith('image/')) throw new Error('Downloaded object is not an image');
    return Buffer.from(await response.arrayBuffer());
  } finally {
    clearTimeout(timeout);
  }
}

function optimizedImageKey(sourceKey: string) {
  return sourceKey.replace(/(\.[a-z0-9]+)?$/i, '.optimized.webp');
}

function clampNumber(value: unknown, min: number, max: number, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.round(parsed)));
}
