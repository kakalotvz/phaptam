import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';

@Processor('rss')
export class RssProcessor extends WorkerHost {
  async process(job: Job) {
    if (job.name !== 'fetch') return;
    // Fetch active RSS sources, normalize feed entries, upsert by link into NewsItem.
    return { ok: true };
  }
}
