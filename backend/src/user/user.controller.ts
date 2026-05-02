import { Body, Controller, Delete, Get, Param, Post, Put, Req, UnauthorizedException } from '@nestjs/common';
import { IsEnum, IsInt, IsOptional, IsString } from 'class-validator';
import { JwtService } from '@nestjs/jwt';
import { FavoriteType, FeedbackType } from '@prisma/client';
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

  @Post('feedback')
  feedback(@Body() dto: FeedbackDto) {
    return this.prisma.feedback.create({ data: { userId: dto.userId || null, content: dto.content, type: dto.type } });
  }
}
