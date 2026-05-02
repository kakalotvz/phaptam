import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { IsEnum, IsInt, IsOptional, IsString } from 'class-validator';
import { FavoriteType, FeedbackType } from '@prisma/client';
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

@Controller()
export class UserController {
  constructor(private readonly prisma: PrismaService) {}

  private readonly mockUserId = 'replace-with-jwt-sub';

  @Post('playlist')
  createPlaylist(@Body() dto: PlaylistDto) {
    return this.prisma.playlist.create({ data: { userId: this.mockUserId, name: dto.name } });
  }

  @Get('playlist')
  playlists() {
    return this.prisma.playlist.findMany({ where: { userId: this.mockUserId }, include: { items: { include: { audio: true }, orderBy: { orderIndex: 'asc' } } } });
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
  favorite(@Body() dto: FavoriteDto) {
    return this.prisma.favorite.upsert({
      where: { userId_type_contentId: { userId: this.mockUserId, type: dto.type, contentId: dto.contentId } },
      update: {},
      create: { userId: this.mockUserId, type: dto.type, contentId: dto.contentId },
    });
  }

  @Get('favorites')
  favorites() {
    return this.prisma.favorite.findMany({ where: { userId: this.mockUserId }, orderBy: { createdAt: 'desc' } });
  }

  @Post('history')
  history(@Body('videoId') videoId: string) {
    return this.prisma.history.create({ data: { userId: this.mockUserId, videoId } });
  }

  @Post('audio-progress')
  progress(@Body() dto: { audioId: string; lastPosition: number }) {
    return this.prisma.audioProgress.upsert({
      where: { userId_audioId: { userId: this.mockUserId, audioId: dto.audioId } },
      update: { lastPosition: dto.lastPosition },
      create: { userId: this.mockUserId, audioId: dto.audioId, lastPosition: dto.lastPosition },
    });
  }

  @Post('feedback')
  feedback(@Body() dto: FeedbackDto) {
    return this.prisma.feedback.create({ data: { userId: dto.userId || null, content: dto.content, type: dto.type } });
  }
}
