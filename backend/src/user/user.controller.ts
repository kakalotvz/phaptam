import { Body, Controller, Delete, Get, NotFoundException, Param, Patch, Post, Put, Req, UnauthorizedException } from '@nestjs/common';
import { IsEnum, IsInt, IsOptional, IsString } from 'class-validator';
import { JwtService } from '@nestjs/jwt';
import { FavoriteType, FeedbackType, ReminderResumeMode } from '@prisma/client';
import { Request } from 'express';
import { PrismaService } from '../prisma/prisma.service';

class PlaylistDto {
  @IsString()
  name!: string;
}

class PlaylistAudioDto {
  @IsString()
  audioId!: string;

  @IsOptional()
  @IsInt()
  orderIndex?: number;
}

class FavoriteDto {
  @IsEnum(FavoriteType)
  type!: FavoriteType;

  @IsString()
  contentId!: string;
}

class FeedbackDto {
  @IsString()
  content!: string;

  @IsEnum(FeedbackType)
  type!: FeedbackType;

  @IsOptional()
  @IsString()
  userId?: string;
}

class ScriptureReminderDto {
  @IsString()
  scriptureId!: string;

  @IsString()
  title!: string;

  @IsString()
  timeOfDay!: string;

  weekdays!: number[];

  @IsEnum(ReminderResumeMode)
  resumeMode!: ReminderResumeMode;

  @IsOptional()
  active?: boolean;

  @IsOptional()
  @IsInt()
  lastLineIndex?: number;
}

@Controller()
export class UserController {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  private async userIdFromRequest(request: Request) {
    const authorization = request.headers.authorization;
    const token = authorization?.startsWith('Bearer ') ? authorization.slice(7) : '';
    if (!token) throw new UnauthorizedException('Bạn cần đăng nhập để thực hiện thao tác này');
    try {
      const payload = await this.jwt.verifyAsync<{ sub?: string }>(token);
      if (!payload.sub) throw new UnauthorizedException('Phiên đăng nhập không hợp lệ');
      return payload.sub;
    } catch {
      throw new UnauthorizedException('Phiên đăng nhập không hợp lệ hoặc đã hết hạn');
    }
  }

  @Post('playlist')
  async createPlaylist(@Req() request: Request, @Body() dto: PlaylistDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.playlist.create({ data: { userId, name: dto.name } });
  }

  @Get('playlist')
  async playlists(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.playlist.findMany({ where: { userId }, include: { items: { include: { audio: true }, orderBy: { orderIndex: 'asc' } } } });
  }

  @Put('playlist/:id')
  renamePlaylist(@Param('id') id: string, @Body() dto: PlaylistDto) {
    return this.prisma.playlist.update({ where: { id }, data: { name: dto.name } });
  }

  @Delete('playlist/:id')
  deletePlaylist(@Param('id') id: string) {
    return this.prisma.playlist.delete({ where: { id } });
  }

  @Post('playlist/:id/add-audio')
  addAudio(@Param('id') playlistId: string, @Body() dto: PlaylistAudioDto) {
    return this.prisma.playlistItem.create({ data: { playlistId, audioId: dto.audioId, orderIndex: dto.orderIndex ?? 0 } });
  }

  @Post('playlist/:id/remove-audio')
  removeAudio(@Param('id') playlistId: string, @Body() dto: PlaylistAudioDto) {
    return this.prisma.playlistItem.delete({ where: { playlistId_audioId: { playlistId, audioId: dto.audioId } } });
  }

  @Post('favorites')
  async favorite(@Req() request: Request, @Body() dto: FavoriteDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.favorite.upsert({
      where: { userId_type_contentId: { userId, type: dto.type, contentId: dto.contentId } },
      update: {},
      create: { userId, type: dto.type, contentId: dto.contentId },
    });
  }

  @Get('favorites')
  async favorites(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.favorite.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  @Post('history')
  async history(@Req() request: Request, @Body('videoId') videoId: string) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.history.create({ data: { userId, videoId } });
  }

  @Post('audio-progress')
  async progress(@Req() request: Request, @Body() dto: { audioId: string; lastPosition: number }) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.audioProgress.upsert({
      where: { userId_audioId: { userId, audioId: dto.audioId } },
      update: { lastPosition: dto.lastPosition },
      create: { userId, audioId: dto.audioId, lastPosition: dto.lastPosition },
    });
  }

  @Get('me/scripture-reminders')
  async scriptureReminders(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.scriptureReminder.findMany({
      where: { userId },
      orderBy: { timeOfDay: 'asc' },
      include: {
        scripture: {
          select: {
            id: true,
            title: true,
            description: true,
            backgroundImageUrl: true,
            lines: {
              orderBy: { orderIndex: 'asc' },
              select: { content: true, startTime: true },
            },
          },
        },
      },
    });
  }

  @Post('me/scripture-reminders')
  async createScriptureReminder(@Req() request: Request, @Body() dto: ScriptureReminderDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.scriptureReminder.create({
      data: {
        userId,
        scriptureId: dto.scriptureId,
        title: dto.title,
        timeOfDay: dto.timeOfDay,
        weekdays: dto.weekdays ?? [],
        resumeMode: dto.resumeMode,
        active: dto.active ?? true,
        lastLineIndex: dto.lastLineIndex ?? 0,
      },
      include: { scripture: { select: { id: true, title: true, description: true, backgroundImageUrl: true, lines: { orderBy: { orderIndex: 'asc' }, select: { content: true, startTime: true } } } } },
    });
  }

  @Patch('me/scripture-reminders/:id')
  async updateScriptureReminder(@Req() request: Request, @Param('id') id: string, @Body() dto: Partial<ScriptureReminderDto>) {
    const userId = await this.userIdFromRequest(request);
    const existing = await this.prisma.scriptureReminder.findFirst({ where: { id, userId }, select: { id: true } });
    if (!existing) throw new NotFoundException('Không tìm thấy lịch nhắc');
    return this.prisma.scriptureReminder.update({
      where: { id },
      data: {
        scriptureId: dto.scriptureId,
        title: dto.title,
        timeOfDay: dto.timeOfDay,
        weekdays: dto.weekdays,
        resumeMode: dto.resumeMode,
        active: dto.active,
        lastLineIndex: dto.lastLineIndex,
      },
      include: { scripture: { select: { id: true, title: true, description: true, backgroundImageUrl: true, lines: { orderBy: { orderIndex: 'asc' }, select: { content: true, startTime: true } } } } },
    });
  }

  @Delete('me/scripture-reminders/:id')
  async deleteScriptureReminder(@Req() request: Request, @Param('id') id: string) {
    const userId = await this.userIdFromRequest(request);
    const existing = await this.prisma.scriptureReminder.findFirst({ where: { id, userId }, select: { id: true } });
    if (!existing) throw new NotFoundException('Không tìm thấy lịch nhắc');
    return this.prisma.scriptureReminder.delete({ where: { id } });
  }

  @Post('feedback')
  feedback(@Body() dto: FeedbackDto) {
    return this.prisma.feedback.create({ data: { userId: dto.userId || null, content: dto.content, type: dto.type } });
  }
}
