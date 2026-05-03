import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AdminAuthGuard } from '../auth/admin.guard';
import { NewsSourceType, ReminderResumeMode, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { generateScriptureTiming, validateScriptureLines } from '../scripture/timing';
import { R2Service } from '../storage/r2.service';

@UseGuards(AdminAuthGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly prisma: PrismaService, private readonly r2: R2Service) {}

  @Get('overview')
  async overview() {
    const [
      audioCount,
      videoCount,
      audioCategoryCount,
      videoCategoryCount,
      rssCount,
      feedbackCount,
      userCount,
      scriptureCount,
      newsCount,
      newsCategoryCount,
      scriptureReminderCount,
      meditationProgramCount,
    ] = await Promise.all([
      this.prisma.audio.count(),
      this.prisma.video.count(),
      this.prisma.audioCategory.count(),
      this.prisma.videoCategory.count(),
      this.prisma.rssSource.count(),
      this.prisma.feedback.count(),
      this.prisma.user.count(),
      this.prisma.scripture.count(),
      this.prisma.newsItem.count(),
      this.prisma.newsCategory.count(),
      this.prisma.scriptureReminder.count(),
      this.prisma.meditationProgram.count(),
    ]);

    return {
      audioCount,
      videoCount,
      audioCategoryCount,
      videoCategoryCount,
      rssCount,
      feedbackCount,
      userCount,
      scriptureCount,
      newsCount,
      newsCategoryCount,
      scriptureReminderCount,
      meditationProgramCount,
    };
  }

  @Get('settings')
  async settings() {
    return {
      contentPageSize: await this.contentPageSize(),
    };
  }

  @Patch('settings')
  async updateSettings(@Body() data: { contentPageSize?: number }) {
    if (data.contentPageSize !== undefined) {
      const pageSize = this.normalizePageSize(data.contentPageSize);
      await this.prisma.appSetting.upsert({
        where: { key: 'contentPageSize' },
        update: { value: String(pageSize) },
        create: { key: 'contentPageSize', value: String(pageSize) },
      });
    }

    return this.settings();
  }

  @Get('r2/usage')
  r2Usage() {
    return this.r2.usage();
  }

  @Get('users')
  users() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        username: true,
        name: true,
        birthDate: true,
        active: true,
        role: true,
        createdAt: true,
        _count: { select: { playlists: true, favorites: true, feedback: true } },
      },
      take: 200,
    });
  }

  @Post('users')
  async createUser(@Body() data: { email: string; username?: string; password: string; name?: string; birthDate?: string; role?: Role; active?: boolean }) {
    return this.prisma.user.create({
      data: {
        email: data.email,
        username: data.username,
        name: data.name,
        birthDate: data.birthDate ? new Date(data.birthDate) : null,
        active: data.active ?? true,
        role: data.role ?? Role.USER,
        passwordHash: await bcrypt.hash(data.password, 12),
      },
      select: { id: true, email: true, username: true, name: true, birthDate: true, active: true, role: true, createdAt: true },
    });
  }

  @Patch('users/:id')
  async updateUser(
    @Param('id') id: string,
    @Body() data: { name?: string; username?: string; email?: string; password?: string; birthDate?: string; active?: boolean; role?: Role },
  ) {
    return this.prisma.user.update({
      where: { id },
      data: {
        name: data.name,
        username: data.username,
        email: data.email,
        passwordHash: data.password ? await bcrypt.hash(data.password, 12) : undefined,
        birthDate: data.birthDate ? new Date(data.birthDate) : undefined,
        active: data.active,
        role: data.role,
      },
      select: { id: true, email: true, username: true, name: true, birthDate: true, active: true, role: true, createdAt: true },
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
  createAudio(@Body() data: { title: string; description?: string; audioUrl: string; thumbnailUrl?: string; categoryId: string; duration?: number }) {
    return this.prisma.audio.create({ data: { ...data, duration: Number(data.duration || 0) } });
  }

  @Patch('audio/:id')
  async updateAudio(@Param('id') id: string, @Body() data: { title?: string; description?: string; audioUrl?: string; thumbnailUrl?: string; categoryId?: string; duration?: number }) {
    const current = await this.prisma.audio.findUniqueOrThrow({ where: { id } });
    const updated = await this.prisma.audio.update({ where: { id }, data });
    await this.deleteReplacedR2Media([
      [current.audioUrl, data.audioUrl],
      [current.thumbnailUrl, data.thumbnailUrl],
    ]);
    return updated;
  }

  @Delete('audio/:id')
  async deleteAudio(@Param('id') id: string) {
    const audio = await this.prisma.audio.findUniqueOrThrow({ where: { id } });
    const deleted = await this.prisma.audio.delete({ where: { id } });
    await this.r2.deletePublicUrls([audio.audioUrl, audio.thumbnailUrl]);
    return deleted;
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
      backgroundImageUrl?: string;
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
        backgroundImageUrl: data.backgroundImageUrl,
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
      backgroundImageUrl?: string;
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
          backgroundImageUrl: data.backgroundImageUrl,
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

  @Get('scripture-reminder')
  scriptureReminders() {
    return this.prisma.scriptureReminder.findMany({
      orderBy: { createdAt: 'desc' },
      include: { scripture: { select: { id: true, title: true } }, user: { select: { id: true, email: true, name: true } } },
      take: 100,
    });
  }

  @Get('scripture-reminders')
  scriptureRemindersAlias() {
    return this.scriptureReminders();
  }

  @Post('scripture-reminder')
  createScriptureReminder(
    @Body()
    data: {
      userId?: string;
      scriptureId: string;
      title?: string;
      timeOfDay: string;
      weekdays: number[];
      resumeMode?: ReminderResumeMode;
      active?: boolean;
    },
  ) {
    return this.prisma.scriptureReminder.create({
      data: {
        userId: data.userId || null,
        scriptureId: data.scriptureId,
        title: data.title?.trim() || 'Nhắc tụng kinh',
        timeOfDay: data.timeOfDay,
        weekdays: data.weekdays ?? [],
        resumeMode: data.resumeMode ?? ReminderResumeMode.RESUME,
        active: data.active ?? true,
      },
      include: { scripture: { select: { id: true, title: true } }, user: { select: { id: true, email: true, name: true } } },
    });
  }

  @Post('scripture-reminders')
  createScriptureReminderAlias(@Body() data: Parameters<AdminController['createScriptureReminder']>[0]) {
    return this.createScriptureReminder(data);
  }

  @Patch('scripture-reminder/:id')
  updateScriptureReminder(
    @Param('id') id: string,
    @Body()
    data: {
      userId?: string;
      scriptureId?: string;
      title?: string;
      timeOfDay?: string;
      weekdays?: number[];
      resumeMode?: ReminderResumeMode;
      active?: boolean;
      lastLineIndex?: number;
    },
  ) {
    return this.prisma.scriptureReminder.update({
      where: { id },
      data: {
        userId: data.userId === undefined ? undefined : data.userId || null,
        scriptureId: data.scriptureId,
        title: data.title,
        timeOfDay: data.timeOfDay,
        weekdays: data.weekdays,
        resumeMode: data.resumeMode,
        active: data.active,
        lastLineIndex: data.lastLineIndex,
      },
      include: { scripture: { select: { id: true, title: true } }, user: { select: { id: true, email: true, name: true } } },
    });
  }

  @Patch('scripture-reminders/:id')
  updateScriptureReminderAlias(
    @Param('id') id: string,
    @Body() data: Parameters<AdminController['updateScriptureReminder']>[1],
  ) {
    return this.updateScriptureReminder(id, data);
  }

  @Delete('scripture-reminder/:id')
  deleteScriptureReminder(@Param('id') id: string) {
    return this.prisma.scriptureReminder.delete({ where: { id } });
  }

  @Delete('scripture-reminders/:id')
  deleteScriptureReminderAlias(@Param('id') id: string) {
    return this.deleteScriptureReminder(id);
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
  async updateVideo(@Param('id') id: string, @Body() data: { title?: string; description?: string; videoUrl?: string; thumbnailUrl?: string; categoryId?: string; teacher?: string }) {
    const current = await this.prisma.video.findUniqueOrThrow({ where: { id } });
    const updated = await this.prisma.video.update({ where: { id }, data });
    await this.deleteReplacedR2Media([
      [current.videoUrl, data.videoUrl],
      [current.thumbnailUrl, data.thumbnailUrl],
    ]);
    return updated;
  }

  @Delete('video/:id')
  async deleteVideo(@Param('id') id: string) {
    const video = await this.prisma.video.findUniqueOrThrow({ where: { id } });
    const deleted = await this.prisma.video.delete({ where: { id } });
    await this.r2.deletePublicUrls([video.videoUrl, video.thumbnailUrl]);
    return deleted;
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

  @Get('meditation')
  meditationPrograms() {
    return this.prisma.meditationProgram.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
  }

  @Post('meditation')
  createMeditationProgram(@Body() data: { title: string; description?: string; duration: number; audioUrl?: string; imageUrl?: string; active?: boolean }) {
    return this.prisma.meditationProgram.create({
      data: { ...data, duration: Number(data.duration || 0), active: data.active ?? true },
    });
  }

  @Patch('meditation/:id')
  updateMeditationProgram(@Param('id') id: string, @Body() data: { title?: string; description?: string; duration?: number; audioUrl?: string; imageUrl?: string; active?: boolean }) {
    return this.prisma.meditationProgram.update({
      where: { id },
      data: { ...data, duration: data.duration === undefined ? undefined : Number(data.duration || 0) },
    });
  }

  @Delete('meditation/:id')
  deleteMeditationProgram(@Param('id') id: string) {
    return this.prisma.meditationProgram.delete({ where: { id } });
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

  @Get('news-category')
  newsCategories() {
    return this.prisma.newsCategory.findMany({ orderBy: { createdAt: 'desc' }, include: { _count: { select: { items: true } } } });
  }

  @Post('news-category')
  createNewsCategory(@Body() data: { name: string; description?: string }) {
    return this.prisma.newsCategory.create({ data });
  }

  @Patch('news-category/:id')
  updateNewsCategory(@Param('id') id: string, @Body() data: { name?: string; description?: string }) {
    return this.prisma.newsCategory.update({ where: { id }, data });
  }

  @Delete('news-category/:id')
  deleteNewsCategory(@Param('id') id: string) {
    return this.prisma.newsCategory.delete({ where: { id } });
  }

  @Get('news')
  newsItems() {
    return this.prisma.newsItem.findMany({
      orderBy: { publishedAt: 'desc' },
      include: { category: true },
      take: 100,
    });
  }

  @Post('news')
  createNewsItem(
    @Body()
    data: {
      title: string;
      summary?: string;
      content?: string;
      imageUrl?: string;
      link?: string;
      categoryId?: string;
      sourceName?: string;
      sourceType?: NewsSourceType;
      shareEnabled?: boolean;
      publishedAt?: string;
    },
  ) {
    return this.prisma.newsItem.create({
      data: {
        title: data.title,
        summary: data.summary,
        content: data.content,
        imageUrl: data.imageUrl,
        link: data.link || null,
        categoryId: data.categoryId || null,
        sourceName: data.sourceName || 'Pháp Tâm',
        sourceType: data.sourceType ?? NewsSourceType.MANUAL,
        shareEnabled: data.shareEnabled ?? true,
        publishedAt: data.publishedAt ? new Date(data.publishedAt) : new Date(),
      },
      include: { category: true },
    });
  }

  @Patch('news/:id')
  async updateNewsItem(
    @Param('id') id: string,
    @Body()
    data: {
      title?: string;
      summary?: string;
      content?: string;
      imageUrl?: string;
      link?: string;
      categoryId?: string;
      sourceName?: string;
      sourceType?: NewsSourceType;
      shareEnabled?: boolean;
      publishedAt?: string;
    },
  ) {
    const current = await this.prisma.newsItem.findUniqueOrThrow({ where: { id } });
    const updated = await this.prisma.newsItem.update({
      where: { id },
      data: {
        title: data.title,
        summary: data.summary,
        content: data.content,
        imageUrl: data.imageUrl,
        link: data.link === undefined ? undefined : data.link || null,
        categoryId: data.categoryId === undefined ? undefined : data.categoryId || null,
        sourceName: data.sourceName,
        sourceType: data.sourceType,
        shareEnabled: data.shareEnabled,
        publishedAt: data.publishedAt ? new Date(data.publishedAt) : undefined,
      },
      include: { category: true },
    });
    await this.deleteReplacedR2Media([[current.imageUrl, data.imageUrl]]);
    await this.r2.deletePublicUrls(removedR2Urls(current.content, data.content));
    return updated;
  }

  @Delete('news/:id')
  async deleteNewsItem(@Param('id') id: string) {
    const item = await this.prisma.newsItem.findUniqueOrThrow({ where: { id } });
    const deleted = await this.prisma.newsItem.delete({ where: { id } });
    await this.r2.deletePublicUrls([item.imageUrl, ...extractUrls(item.content)]);
    return deleted;
  }

  @Get('feedback')
  feedback() {
    return this.prisma.feedback.findMany({ orderBy: { createdAt: 'desc' }, include: { user: { select: { id: true, email: true, username: true, name: true } } }, take: 100 });
  }

  @Delete('feedback/:id')
  deleteFeedback(@Param('id') id: string) {
    return this.prisma.feedback.delete({ where: { id } });
  }

  private async deleteReplacedR2Media(pairs: Array<[string | null | undefined, string | null | undefined]>) {
    await this.r2.deletePublicUrls(pairs.filter(([previous, next]) => next !== undefined && previous !== next).map(([previous]) => previous));
  }

  private async contentPageSize() {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'contentPageSize' } });
    return this.normalizePageSize(setting?.value ?? 10);
  }

  private normalizePageSize(value: unknown) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return 10;
    return Math.min(100, Math.max(1, Math.round(parsed)));
  }
}

function extractUrls(value?: string | null) {
  if (!value) return [];
  return Array.from(value.matchAll(/https?:\/\/[^\s"'<>]+/g)).map((match) => match[0]);
}

function removedR2Urls(previous?: string | null, next?: string | null) {
  const nextUrls = new Set(extractUrls(next));
  return extractUrls(previous).filter((url) => !nextUrls.has(url));
}
