import { Processor, WorkerHost } from '@nestjs/bullmq';
import { NewsContentType, NewsSourceType } from '@prisma/client';
import { Job } from 'bullmq';
import { lookup } from 'dns/promises';
import FeedParser = require('feedparser');
import { isIP } from 'net';
import { Readable } from 'stream';
import { PrismaService } from '../prisma/prisma.service';

@Processor('rss')
export class RssProcessor extends WorkerHost {
  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job) {
    if (job.name !== 'fetch') return;
    const sources = await this.prisma.rssSource.findMany({ where: { active: true } });
    const results = await Promise.allSettled(sources.map((source) => this.fetchSource(source.id, source.name, source.url)));
    return {
      ok: true,
      sources: sources.length,
      imported: results.reduce((sum, result) => sum + (result.status === 'fulfilled' ? result.value : 0), 0),
      failed: results.filter((result) => result.status === 'rejected').length,
    };
  }

  private async fetchSource(sourceId: string, sourceName: string, rawUrl: string) {
    const url = await resolveSafeRssUrl(rawUrl);
    const response = await fetchWithRedirects(url);
    const xml = await response.text();
    const items = await parseFeed(xml);
    let imported = 0;

    for (const item of items.slice(0, 50)) {
      const link = safeText(item.link || item.origlink || item.guid);
      const title = safeText(item.title);
      if (!link || !title) continue;
      await this.prisma.newsItem.upsert({
        where: { link },
        update: {
          title,
          summary: safeText(item.summary || item.description) || undefined,
          sourceName,
          sourceType: NewsSourceType.RSS,
          contentType: NewsContentType.NEWS,
          publishedAt: item.pubdate || item.date || undefined,
        },
        create: {
          sourceId,
          title,
          link,
          summary: safeText(item.summary || item.description) || undefined,
          sourceName,
          sourceType: NewsSourceType.RSS,
          contentType: NewsContentType.NEWS,
          publishedAt: item.pubdate || item.date || new Date(),
        },
      });
      imported += 1;
    }

    return imported;
  }
}

async function fetchWithRedirects(initialUrl: URL, redirects = 0): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10_000);
  try {
    const response = await fetch(initialUrl, {
      headers: { Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.5' },
      redirect: 'manual',
      signal: controller.signal,
    });

    if ([301, 302, 303, 307, 308].includes(response.status)) {
      if (redirects >= 3) throw new Error('RSS source redirects too many times');
      const location = response.headers.get('location');
      if (!location) throw new Error('RSS redirect is missing Location header');
      return fetchWithRedirects(await resolveSafeRssUrl(new URL(location, initialUrl).toString()), redirects + 1);
    }

    if (!response.ok) throw new Error(`RSS source returned ${response.status}`);
    return response;
  } finally {
    clearTimeout(timeout);
  }
}

async function resolveSafeRssUrl(rawUrl: string) {
  const url = new URL(rawUrl);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('RSS source must use HTTP or HTTPS');
  if (url.username || url.password) throw new Error('RSS source must not include credentials');

  const records = await lookup(url.hostname, { all: true, verbatim: true });
  if (records.length === 0 || records.some((record) => isPrivateAddress(record.address))) {
    throw new Error('RSS source resolves to a private or unsafe address');
  }
  return url;
}

function isPrivateAddress(address: string) {
  if (address === '::1' || address.toLowerCase().startsWith('fe80:') || address.toLowerCase().startsWith('fc') || address.toLowerCase().startsWith('fd')) {
    return true;
  }
  if (isIP(address) !== 4) return false;
  const [a, b] = address.split('.').map(Number);
  return (
    a === 10 ||
    a === 127 ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    a === 0
  );
}

function parseFeed(xml: string) {
  return new Promise<FeedParser.Item[]>((resolve, reject) => {
    const parser = new FeedParser({});
    const items: FeedParser.Item[] = [];
    parser.on('error', reject);
    parser.on('readable', function readItems(this: FeedParser) {
      let item: FeedParser.Item | null;
      while ((item = this.read() as FeedParser.Item | null)) {
        items.push(item);
      }
    });
    parser.on('end', () => resolve(items));
    Readable.from([xml]).pipe(parser);
  });
}

function safeText(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}
