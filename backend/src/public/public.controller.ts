import { Controller, Get, Query } from '@nestjs/common';
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

  @Get('video')
  video(@Query('category_id') categoryId?: string) {
    return this.prisma.video.findMany({ where: { categoryId }, include: { category: true }, take: 30 });
  }

  @Get('news')
  news() {
    return this.prisma.newsItem.findMany({ orderBy: { publishedAt: 'desc' }, take: 30 });
  }
}
