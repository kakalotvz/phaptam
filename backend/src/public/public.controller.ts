import { Controller, Get, Param, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller()
export class PublicController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('categories/audio')
  audioCategories() {
    return this.prisma.audioCategory.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Get('categories/video')
  videoCategories() {
    return this.prisma.videoCategory.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Get('audio')
  audio(@Query('category_id') categoryId?: string) {
    return this.prisma.audio.findMany({ where: { categoryId }, include: { category: true }, take: 30 });
  }

  @Get('scriptures')
  scriptures(@Query('category_id') categoryId?: string) {
    return this.prisma.scripture.findMany({
      where: { categoryId },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        title: true,
        description: true,
        backgroundImageUrl: true,
        categoryId: true,
        category: true,
        lines: {
          orderBy: { orderIndex: 'asc' },
          select: { content: true, startTime: true },
        },
        _count: { select: { lines: true } },
      },
      take: 30,
    });
  }

  @Get('scriptures/:id')
  async scripture(@Param('id') id: string) {
    const scripture = await this.prisma.scripture.findUniqueOrThrow({
      where: { id },
      select: {
        id: true,
        title: true,
        description: true,
        backgroundImageUrl: true,
        categoryId: true,
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

  @Get('video')
  video(@Query('category_id') categoryId?: string) {
    return this.prisma.video.findMany({ where: { categoryId }, include: { category: true }, take: 30 });
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
  quotes() {
    return this.prisma.quote.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
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
    return this.prisma.newsCategory.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Get('news')
  news(@Query('category_id') categoryId?: string) {
    return this.prisma.newsItem.findMany({
      where: { categoryId },
      orderBy: { publishedAt: 'desc' },
      include: { category: true },
      take: 30,
    });
  }

  @Get('news/:id')
  newsItem(@Param('id') id: string) {
    return this.prisma.newsItem.findUniqueOrThrow({
      where: { id },
      include: { category: true },
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
}
