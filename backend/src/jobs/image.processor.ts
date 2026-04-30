import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';

@Processor('image')
export class ImageProcessor extends WorkerHost {
  async process(job: Job) {
    if (job.name !== 'optimize') return;
    // Download original image, resize with Sharp, convert to WebP 70-85 quality, upload optimized only.
    return { ok: true };
  }
}
