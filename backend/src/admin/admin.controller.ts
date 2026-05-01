import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { generateScriptureTiming, validateScriptureLines } from '../scripture/timing';

@Controller('admin')
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('overview')
  async overview() {
    const [audioCount, videoCount, audioCategoryCount, videoCategoryCount, rssCount, feedbackCount, userCount, scriptureCount] = await Promise.all([
      this.prisma.audio.count(),
      this.prisma.video.count(),
      this.prisma.audioCategory.count(),
      this.prisma.videoCategory.count(),
      this.prisma.rssSource.count(),
      this.prisma.feedback.count(),
      this.prisma.user.count(),
      this.prisma.scripture.count(),
    ]);

    return { audioCount, videoCount, audioCategoryCount, videoCategoryCount, rssCount, feedbackCount, userCount, scriptureCount };
  }

  @Get('users')
  users() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        createdAt: true,
        _count: { select: { playlists: true, favorites: true, feedback: true } },
      },
      take: 200,
    });
  }

  @Post('users')
  async createUser(@Body() data: { email: string; password: string; name?: string; role?: Role }) {
    return this.prisma.user.create({
      data: {
        email: data.email,
        name: data.name,
        role: data.role ?? Role.USER,
        passwordHash: await bcrypt.hash(data.password, 12),
      },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
  }

  @Patch('users/:id')
  updateUser(@Param('id') id: string, @Body() data: { name?: string; role?: Role }) {
    return this.prisma.user.update({
      where: { id },
      data,
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string) {
    return this.prisma.user.delete({ where: { id } });
  }

  @Get('audio-category')
  audioCategories() {
    return this.prisma.audioCategory.findMany({ orderBy: { createdAt: 'desc' }, include: { _count: { select: { audios: true } } } });
  }

  @Post('audio-category')
  createAudioCategory(@Body() data: { name: string; description?: string }) {
    return this.prisma.audioCategory.create({ data });
  }

  @Patch('audio-category/:id')
  updateAudioCategory(@Param('id') id: string, @Body() data: { name?: string; description?: string }) {
    return this.prisma.audioCategory.update({ where: { id }, data });
  }

  @Delete('audio-category/:id')
  deleteAudioCategory(@Param('id') id: string) {
    return this.prisma.audioCategory.delete({ where: { id } });
  }

  @Get('video-category')
  videoCategories() {
    return this.prisma.videoCategory.findMany({ orderBy: { createdAt: 'desc' }, include: { _count: { select: { videos: true } } } });
  }

  @Post('video-category')
  createVideoCategory(@Body() data: { name: string; description?: string }) {
    return this.prisma.videoCategory.create({ data });
  }

  @Patch('video-category/:id')
  updateVideoCategory(@Param('id') id: string, @Body() data: { name?: string; description?: string }) {
    return this.prisma.videoCategory.update({ where: { id }, data });
  }

  @Delete('video-category/:id')
  deleteVideoCategory(@Param('id') id: string) {
    return this.prisma.videoCategory.delete({ where: { id } });
  }

  @Get('audio')
  audios() {
    return this.prisma.audio.findMany({ orderBy: { createdAt: 'desc' }, include: { category: true }, take: 100 });
  }

  @Post('audio')
  createAudio(@Body() data: { title: string; description?: string; audioUrl: string; thumbnailUrl?: string; categoryId: string; duration: number }) {
    return this.prisma.audio.create({ data });
  }

  @Patch('audio/:id')
  updateAudio(@Param('id') id: string, @Body() data: { title?: string; description?: string; audioUrl?: string; thumbnailUrl?: string; categoryId?: string; duration?: number }) {
    return this.prisma.audio.update({ where: { id }, data });
  }

  @Delete('audio/:id')
  deleteAudio(@Param('id') id: string) {
    return this.prisma.audio.delete({ where: { id } });
  }

  @Get('scripture')
  scriptures() {
    return this.prisma.scripture.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        category: true,
        lines: { orderBy: { orderIndex: 'asc' } },
      },
      take: 100,
    });
  }

  @Post('scripture/generate-timing')
  generateScriptureTiming(@Body() data: { lines: string[]; audioDuration?: number }) {
    return generateScriptureTiming(data.lines ?? [], Number(data.audioDuration || 0) || undefined);
  }

  @Post('scripture')
  async createScripture(
    @Body()
    data: {
      title: string;
      description?: string;
      categoryId?: string;
      lines: Array<{ content: string; start_time?: number; startTime?: number }>;
    },
  ) {
    const lines = (data.lines ?? []).map((line) => ({
      content: line.content,
      start_time: Number(line.start_time ?? line.startTime),
    }));

    try {
      validateScriptureLines(lines);
    } catch (error) {
      throw new BadRequestException(error instanceof Error ? error.message : 'Dữ liệu dòng kinh không hợp lệ');
    }

    return this.prisma.scripture.create({
      data: {
        title: data.title,
        description: data.description,
        categoryId: data.categoryId || null,
        lines: {
          create: lines.map((line, orderIndex) => ({
            content: line.content.trim(),
            startTime: line.start_time,
            orderIndex,
          })),
        },
      },
      include: {
        category: true,
        lines: { orderBy: { orderIndex: 'asc' } },
      },
    });
  }

  @Patch('scripture/:id')
  async updateScripture(
    @Param('id') id: string,
    @Body()
    data: {
      title?: string;
      description?: string;
      categoryId?: string;
      lines?: Array<{ content: string; start_time?: number; startTime?: number }>;
    },
  ) {
    const lines = data.lines?.map((line) => ({
      content: line.content,
      start_time: Number(line.start_time ?? line.startTime),
    }));

    if (lines) {
      try {
        validateScriptureLines(lines);
      } catch (error) {
        throw new BadRequestException(error instanceof Error ? error.message : 'Dữ liệu dòng kinh không hợp lệ');
      }
    }

    return this.prisma.$transaction(async (tx) => {
      if (lines) {
        await tx.scriptureLine.deleteMany({ where: { scriptureId: id } });
      }

      return tx.scripture.update({
        where: { id },
        data: {
          title: data.title,
          description: data.description,
          categoryId: data.categoryId === undefined ? undefined : data.categoryId || null,
          lines: lines
            ? {
                create: lines.map((line, orderIndex) => ({
                  content: line.content.trim(),
                  startTime: line.start_time,
                  orderIndex,
                })),
              }
            : undefined,
        },
        include: {
          category: true,
          lines: { orderBy: { orderIndex: 'asc' } },
        },
      });
    });
  }

  @Delete('scripture/:id')
  deleteScripture(@Param('id') id: string) {
    return this.prisma.scripture.delete({ where: { id } });
  }

  @Get('video')
  videos() {
    return this.prisma.video.findMany({ orderBy: { createdAt: 'desc' }, include: { category: true }, take: 100 });
  }

  @Post('video')
  createVideo(@Body() data: { title: string; description?: string; videoUrl: string; thumbnailUrl?: string; categoryId: string; teacher?: string }) {
    return this.prisma.video.create({ data });
  }

  @Patch('video/:id')
  updateVideo(@Param('id') id: string, @Body() data: { title?: string; description?: string; videoUrl?: string; thumbnailUrl?: string; categoryId?: string; teacher?: string }) {
    return this.prisma.video.update({ where: { id }, data });
  }

  @Delete('video/:id')
  deleteVideo(@Param('id') id: string) {
    return this.prisma.video.delete({ where: { id } });
  }

  @Get('banner')
  banners() {
    return this.prisma.banner.findMany({ orderBy: { createdAt: 'desc' }, take: 50 });
  }

  @Post('banner')
  createBanner(@Body() data: { imageUrl: string; link?: string }) {
    return this.prisma.banner.create({ data });
  }

  @Patch('banner/:id')
  updateBanner(@Param('id') id: string, @Body() data: { imageUrl?: string; link?: string; active?: boolean }) {
    return this.prisma.banner.update({ where: { id }, data });
  }

  @Delete('banner/:id')
  deleteBanner(@Param('id') id: string) {
    return this.prisma.banner.delete({ where: { id } });
  }

  @Get('quote')
  quotes() {
    return this.prisma.quote.findMany({ orderBy: { createdAt: 'desc' }, take: 50 });
  }

  @Post('quote')
  createQuote(@Body() data: { content: string; imageUrl?: string }) {
    return this.prisma.quote.create({ data });
  }

  @Patch('quote/:id')
  updateQuote(@Param('id') id: string, @Body() data: { content?: string; imageUrl?: string; active?: boolean }) {
    return this.prisma.quote.update({ where: { id }, data });
  }

  @Delete('quote/:id')
  deleteQuote(@Param('id') id: string) {
    return this.prisma.quote.delete({ where: { id } });
  }

  @Get('rss')
  rssSources() {
    return this.prisma.rssSource.findMany({ orderBy: { createdAt: 'desc' } });
  }

  @Post('rss')
  createRss(@Body() data: { name: string; url: string; active?: boolean }) {
    return this.prisma.rssSource.create({ data });
  }

  @Patch('rss/:id')
  updateRss(@Param('id') id: string, @Body() data: { name?: string; url?: string; active?: boolean }) {
    return this.prisma.rssSource.update({ where: { id }, data });
  }

  @Delete('rss/:id')
  deleteRss(@Param('id') id: string) {
    return this.prisma.rssSource.delete({ where: { id } });
  }

  @Get('feedback')
  feedback() {
    return this.prisma.feedback.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
  }

  @Delete('feedback/:id')
  deleteFeedback(@Param('id') id: string) {
    return this.prisma.feedback.delete({ where: { id } });
  }
}
