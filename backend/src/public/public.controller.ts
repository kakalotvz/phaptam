import { Controller, Get, Param, Post, Query } from '@nestjs/common';
import { NewsContentType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const scriptureCategoryInclude = {
  parent: {
    include: {
      parent: {
        include: {
          parent: {
            include: {
              parent: {
                include: {
                  parent: true,
                },
              },
            },
          },
        },
      },
    },
  },
} as const;

@Controller()
export class PublicController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('categories/audio')
  audioCategories() {
    return this.prisma.audioCategory.findMany({
      where: { kind: 'AUDIO', audios: { some: {} } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Get('categories/video')
  videoCategories() {
    return this.prisma.videoCategory.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Get('audio')
  async audio(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    if (pagination == null) {
      return this.prisma.audio.findMany({
        where: { categoryId },
        include: { category: true },
        take: 30,
      });
    }
    const items = await this.prisma.audio.findMany({
      where: { categoryId },
      include: { category: true },
      take: pagination.limit,
      skip: pagination.skip,
    });
    return paginated(items, pagination);
  }

  @Post('audio/:id/view')
  audioView(@Param('id') id: string) {
    return this.prisma.audio.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
      select: { id: true, viewCount: true },
    });
  }

  @Get('scriptures')
  async scriptures(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    const query = {
      where: { kind: 'CHANT' as const, categoryId },
      orderBy: { createdAt: 'desc' as const },
      select: {
        id: true,
        title: true,
        description: true,
        kind: true,
        backgroundImageUrl: true,
        categoryId: true,
        category: { include: scriptureCategoryInclude },
        viewCount: true,
        createdAt: true,
        lines: {
          orderBy: { orderIndex: 'asc' as const },
          select: { content: true, startTime: true },
        },
        _count: { select: { lines: true } },
      },
    };
    if (pagination == null) {
      return this.prisma.scripture.findMany({
        ...query,
        take: 30,
      });
    }
    const items = await this.prisma.scripture.findMany({
      ...query,
      take: pagination.limit,
      skip: pagination.skip,
    });
    return paginated(items, pagination);
  }

  @Get('scriptures/:id')
  async scripture(@Param('id') id: string) {
    const scripture = await this.prisma.scripture.findUniqueOrThrow({
      where: { id },
      select: {
        id: true,
        title: true,
        description: true,
        kind: true,
        backgroundImageUrl: true,
        categoryId: true,
        category: { include: scriptureCategoryInclude },
        lines: {
          orderBy: { orderIndex: 'asc' },
          select: { content: true, startTime: true },
        },
      },
    });

    return {
      ...scripture,
      lines: scripture.lines.map((line) => ({
        content: line.content,
        start_time: line.startTime,
      })),
    };
  }

  @Post('scriptures/:id/view')
  scriptureView(@Param('id') id: string) {
    return this.prisma.scripture.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
      select: { id: true, viewCount: true },
    });
  }

  @Get('scripture-readings')
  async scriptureReadings(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    const query = {
      where: { kind: 'READING' as const, categoryId },
      orderBy: { createdAt: 'desc' as const },
      select: {
        id: true,
        kind: true,
        title: true,
        description: true,
        content: true,
        categoryId: true,
        category: { include: scriptureCategoryInclude },
        viewCount: true,
        createdAt: true,
      },
    };
    if (pagination == null) {
      return this.prisma.scripture.findMany({
        ...query,
        take: 50,
      });
    }
    const items = await this.prisma.scripture.findMany({
      ...query,
      take: pagination.limit,
      skip: pagination.skip,
    });
    return paginated(items, pagination);
  }

  @Get('scripture-readings/:id')
  scriptureReading(@Param('id') id: string) {
    return this.prisma.scripture.findUniqueOrThrow({
      where: { id },
      select: {
        id: true,
        kind: true,
        title: true,
        description: true,
        content: true,
        categoryId: true,
        category: { include: scriptureCategoryInclude },
        viewCount: true,
        createdAt: true,
      },
    });
  }

  @Post('scripture-readings/:id/view')
  scriptureReadingView(@Param('id') id: string) {
    return this.prisma.scripture.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
      select: { id: true, viewCount: true },
    });
  }

  @Get('video')
  async video(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    if (pagination == null) {
      return this.prisma.video.findMany({
        where: { categoryId },
        include: { category: true },
        take: 30,
      });
    }
    const items = await this.prisma.video.findMany({
      where: { categoryId },
      include: { category: true },
      take: pagination.limit,
      skip: pagination.skip,
    });
    return paginated(items, pagination);
  }

  @Post('video/:id/view')
  videoView(@Param('id') id: string) {
    return this.prisma.video.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
      select: { id: true, viewCount: true },
    });
  }

  @Get('meditation')
  meditationPrograms() {
    return this.prisma.meditationProgram.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
  }

  @Get('quotes')
  async quotes() {
    const currentQuoteId = await this.syncQuoteRotation();
    return this.prisma.quote.findMany({
      where: currentQuoteId ? { id: currentQuoteId } : { active: true },
      orderBy: { createdAt: 'desc' },
      take: 1,
    });
  }

  @Get('quote-backgrounds')
  async quoteBackgrounds() {
    return (await this.quoteBackgroundSettings()).filter((item) => item.active);
  }

  @Get('banners')
  banners() {
    return this.prisma.banner.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });
  }

  @Get('news/categories')
  newsCategories() {
    return this.prisma.newsCategory.findMany({ where: { contentType: NewsContentType.NEWS }, orderBy: { createdAt: 'desc' } });
  }

  @Get('news')
  async news(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    const where = { categoryId, contentType: NewsContentType.NEWS };
    if (pagination == null) {
      return this.prisma.newsItem.findMany({
        where,
        orderBy: { publishedAt: 'desc' },
        include: { category: true },
      });
    }
    const [items, total] = await this.prisma.$transaction([
      this.prisma.newsItem.findMany({
        where,
        orderBy: { publishedAt: 'desc' },
        include: { category: true },
        take: pagination.limit,
        skip: pagination.skip,
      }),
      this.prisma.newsItem.count({ where }),
    ]);
    return paginated(items, pagination, { total });
  }

  @Get('knowledge/categories')
  knowledgeCategories() {
    return this.prisma.newsCategory.findMany({ where: { contentType: NewsContentType.KNOWLEDGE }, orderBy: { createdAt: 'desc' } });
  }

  @Get('knowledge')
  async knowledge(
    @Query('category_id') categoryId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const pagination = parsePagination(page, limit);
    const where = { categoryId, contentType: NewsContentType.KNOWLEDGE };
    if (pagination == null) {
      return this.prisma.newsItem.findMany({
        where,
        orderBy: { publishedAt: 'desc' },
        include: { category: true },
      });
    }
    const [items, total] = await this.prisma.$transaction([
      this.prisma.newsItem.findMany({
        where,
        orderBy: { publishedAt: 'desc' },
        include: { category: true },
        take: pagination.limit,
        skip: pagination.skip,
      }),
      this.prisma.newsItem.count({ where }),
    ]);
    return paginated(items, pagination, { total });
  }

  @Get('news/:id')
  newsItem(@Param('id') id: string) {
    return this.prisma.newsItem.findUniqueOrThrow({
      where: { id },
      include: { category: true },
    });
  }

  @Post('news/:id/view')
  newsView(@Param('id') id: string) {
    return this.prisma.newsItem.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
      select: { id: true, viewCount: true },
    });
  }

  @Get('scripture-reminders')
  scriptureReminders(@Query('user_id') userId?: string) {
    return this.prisma.scriptureReminder.findMany({
      where: {
        active: true,
        userId: userId || null,
      },
      orderBy: { timeOfDay: 'asc' },
      include: {
        scripture: {
          select: { id: true, title: true, description: true },
        },
      },
      take: 50,
    });
  }

  private async syncQuoteRotation() {
    const settings = await this.quoteRotationSettings();
    if (!settings.enabled || settings.paused || settings.quoteIds.length === 0) {
      return (await this.prisma.quote.findFirst({ where: { active: true }, select: { id: true } }))?.id ?? null;
    }

    const existing = await this.prisma.quote.findMany({
      where: { id: { in: settings.quoteIds } },
      select: { id: true },
    });
    const validIds = settings.quoteIds.filter((id) => existing.some((item) => item.id === id));
    if (validIds.length === 0) return null;

    const currentQuoteId = validIds[quoteRotationIndex(settings, validIds.length)];
    await this.prisma.$transaction([
      this.prisma.quote.updateMany({ where: { id: { not: currentQuoteId } }, data: { active: false } }),
      this.prisma.quote.update({ where: { id: currentQuoteId }, data: { active: true } }),
    ]);
    return currentQuoteId;
  }

  private async quoteRotationSettings(): Promise<QuoteRotationSettings> {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: quoteRotationKey } });
    if (!setting) return defaultQuoteRotationSettings();
    try {
      const parsed = JSON.parse(setting.value) as Partial<QuoteRotationSettings>;
      return {
        enabled: Boolean(parsed.enabled),
        paused: Boolean(parsed.paused),
        quoteIds: Array.isArray(parsed.quoteIds) ? uniqueStrings(parsed.quoteIds) : [],
        startDate: typeof parsed.startDate === 'string' ? parsed.startDate : vietnamDateKey(new Date()),
        offset: Number.isFinite(Number(parsed.offset)) ? Number(parsed.offset) : 0,
      };
    } catch {
      return defaultQuoteRotationSettings();
    }
  }

  private async quoteBackgroundSettings(): Promise<QuoteBackgroundSettings> {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: quoteBackgroundKey } });
    if (!setting) return [];
    try {
      const parsed = JSON.parse(setting.value) as unknown;
      if (!Array.isArray(parsed)) return [];
      return parsed
        .map((item) => normalizeQuoteBackground(item))
        .filter((item): item is QuoteBackground => item !== null);
    } catch {
      return [];
    }
  }
}

const quoteRotationKey = 'quoteRotation';
const quoteBackgroundKey = 'quoteBackgrounds';

type QuoteRotationSettings = {
  enabled: boolean;
  paused: boolean;
  quoteIds: string[];
  startDate: string;
  offset: number;
};

type QuoteBackground = {
  id: string;
  imageUrl: string;
  name: string;
  sizeBytes?: number;
  width?: number;
  height?: number;
  active: boolean;
  createdAt: string;
};

type QuoteBackgroundSettings = QuoteBackground[];

function defaultQuoteRotationSettings(): QuoteRotationSettings {
  return { enabled: false, paused: false, quoteIds: [], startDate: vietnamDateKey(new Date()), offset: 0 };
}

function uniqueStrings(values: unknown[]) {
  return Array.from(new Set(values.filter((value): value is string => typeof value === 'string' && value.trim().length > 0)));
}

function normalizeQuoteBackground(value: unknown): QuoteBackground | null {
  if (!value || typeof value !== 'object') return null;
  const item = value as Partial<QuoteBackground>;
  if (typeof item.id !== 'string' || typeof item.imageUrl !== 'string' || !item.imageUrl.trim()) return null;
  return {
    id: item.id,
    imageUrl: item.imageUrl.trim(),
    name: typeof item.name === 'string' && item.name.trim() ? item.name.trim() : 'Ảnh nền trích dẫn',
    sizeBytes: normalizePositiveNumber(item.sizeBytes),
    width: normalizePositiveNumber(item.width),
    height: normalizePositiveNumber(item.height),
    active: item.active !== false,
    createdAt: typeof item.createdAt === 'string' ? item.createdAt : new Date().toISOString(),
  };
}

function normalizePositiveNumber(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed) : undefined;
}

function vietnamDateKey(date: Date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function quoteRotationIndex(settings: QuoteRotationSettings, length: number) {
  const start = Date.parse(`${settings.startDate}T00:00:00+07:00`);
  const today = Date.parse(`${vietnamDateKey(new Date())}T00:00:00+07:00`);
  const days = Number.isFinite(start) && Number.isFinite(today)
    ? Math.max(0, Math.floor((today - start) / 86_400_000))
    : 0;
  return positiveModulo(days + settings.offset, length);
}

function positiveModulo(value: number, length: number) {
  return ((value % length) + length) % length;
}

function parsePagination(page?: string, limit?: string) {
  const parsedPage = Number(page);
  const parsedLimit = Number(limit);
  if (!Number.isFinite(parsedPage) || !Number.isFinite(parsedLimit)) return null;
  const safePage = Math.max(1, Math.floor(parsedPage));
  const safeLimit = Math.min(20, Math.max(1, Math.floor(parsedLimit)));
  return {
    page: safePage,
    limit: safeLimit,
    skip: (safePage - 1) * safeLimit,
  };
}

function paginated<T>(
  items: T[],
  pagination: { page: number; limit: number; skip: number },
  options: { total?: number } = {},
) {
  const total = options.total ?? pagination.skip + items.length + (items.length == pagination.limit ? 1 : 0);
  return {
    items,
    page: pagination.page,
    limit: pagination.limit,
    hasMore: pagination.skip + items.length < total,
  };
}
