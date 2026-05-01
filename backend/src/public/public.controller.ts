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
        categoryId: true,
        category: true,
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

  @Get('news')
  news() {
    return this.prisma.newsItem.findMany({ orderBy: { publishedAt: 'desc' }, take: 30 });
  }
}
