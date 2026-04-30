import { Body, Controller, Get, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin')
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  @Post('audio-category')
  createAudioCategory(@Body() data: { name: string; description?: string }) {
    return this.prisma.audioCategory.create({ data });
  }

  @Post('video-category')
  createVideoCategory(@Body() data: { name: string; description?: string }) {
    return this.prisma.videoCategory.create({ data });
  }

  @Post('audio')
  createAudio(@Body() data: { title: string; description?: string; audioUrl: string; thumbnailUrl?: string; categoryId: string; duration: number }) {
    return this.prisma.audio.create({ data });
  }

  @Post('video')
  createVideo(@Body() data: { title: string; description?: string; videoUrl: string; thumbnailUrl?: string; categoryId: string; teacher?: string }) {
    return this.prisma.video.create({ data });
  }

  @Post('banner')
  createBanner(@Body() data: { imageUrl: string; link?: string }) {
    return this.prisma.banner.create({ data });
  }

  @Post('quote')
  createQuote(@Body() data: { content: string; imageUrl?: string }) {
    return this.prisma.quote.create({ data });
  }

  @Post('rss')
  createRss(@Body() data: { name: string; url: string; active?: boolean }) {
    return this.prisma.rssSource.create({ data });
  }

  @Get('feedback')
  feedback() {
    return this.prisma.feedback.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
  }
}
