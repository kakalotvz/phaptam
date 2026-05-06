import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UnauthorizedException,
} from "@nestjs/common";
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsEmail,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from "class-validator";
import { JwtService } from "@nestjs/jwt";
import { FavoriteType, FeedbackType, ReminderResumeMode } from "@prisma/client";
import { Request } from "express";
import { PrismaService } from "../prisma/prisma.service";

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

class UserDownloadDto {
  @IsString()
  mediaKey!: string;

  @IsString()
  mediaType!: string;

  @IsString()
  contentId!: string;

  @IsString()
  title!: string;

  @IsString()
  url!: string;

  @IsOptional()
  @IsString()
  thumbnailUrl?: string;
}

class FeedbackDto {
  @IsString()
  content!: string;

  @IsEnum(FeedbackType)
  type!: FeedbackType;

  @IsOptional()
  @IsString()
  guestName?: string;

  @IsOptional()
  @IsEmail()
  guestEmail?: string;
}

class HistoryDto {
  @IsString()
  videoId!: string;
}

class AudioProgressDto {
  @IsString()
  audioId!: string;

  @IsNumber()
  @Min(0)
  lastPosition!: number;
}

class ScriptureReminderDto {
  @IsString()
  scriptureId!: string;

  @IsString()
  title!: string;

  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  timeOfDay!: string;

  @IsArray()
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(6, { each: true })
  weekdays!: number[];

  @IsEnum(ReminderResumeMode)
  resumeMode!: ReminderResumeMode;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  lastLineIndex?: number;
}

class UpdateScriptureReminderDto {
  @IsOptional()
  @IsString()
  scriptureId?: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  timeOfDay?: string;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(6, { each: true })
  weekdays?: number[];

  @IsOptional()
  @IsEnum(ReminderResumeMode)
  resumeMode?: ReminderResumeMode;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  lastLineIndex?: number;
}

class ScriptureReadingPreferenceDto {
  @IsIn(["GLOBAL", "SCRIPTURE"])
  scope!: "GLOBAL" | "SCRIPTURE";

  @IsOptional()
  @IsString()
  scriptureId?: string;

  @IsNumber()
  @Min(0.25)
  @Max(3)
  speed!: number;

  @IsIn(["slow", "normal", "fast", "custom"])
  speedMode!: string;
}

@Controller()
export class UserController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  private async userIdFromRequest(request: Request) {
    const authorization = request.headers.authorization;
    const token = authorization?.startsWith("Bearer ")
      ? authorization.slice(7)
      : "";
    if (!token)
      throw new UnauthorizedException(
        "Bạn cần đăng nhập để thực hiện thao tác này",
      );
    try {
      const payload = await this.jwt.verifyAsync<{ sub?: string }>(token);
      if (!payload.sub)
        throw new UnauthorizedException("Phiên đăng nhập không hợp lệ");
      return payload.sub;
    } catch {
      throw new UnauthorizedException(
        "Phiên đăng nhập không hợp lệ hoặc đã hết hạn",
      );
    }
  }

  private async optionalUserIdFromRequest(request: Request) {
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith("Bearer ")) return undefined;
    return this.userIdFromRequest(request);
  }

  private async ensurePlaylistOwner(playlistId: string, userId: string) {
    const playlist = await this.prisma.playlist.findFirst({
      where: { id: playlistId, userId },
      select: { id: true },
    });
    if (!playlist) throw new NotFoundException("Không tìm thấy danh sách phát");
  }

  @Post("playlist")
  async createPlaylist(@Req() request: Request, @Body() dto: PlaylistDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.playlist.create({ data: { userId, name: dto.name } });
  }

  @Get("playlist")
  async playlists(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.playlist.findMany({
      where: { userId },
      include: {
        items: { include: { audio: true }, orderBy: { orderIndex: "asc" } },
      },
    });
  }

  @Put("playlist/:id")
  async renamePlaylist(
    @Req() request: Request,
    @Param("id") id: string,
    @Body() dto: PlaylistDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    await this.ensurePlaylistOwner(id, userId);
    return this.prisma.playlist.update({
      where: { id },
      data: { name: dto.name },
    });
  }

  @Delete("playlist/:id")
  async deletePlaylist(@Req() request: Request, @Param("id") id: string) {
    const userId = await this.userIdFromRequest(request);
    await this.ensurePlaylistOwner(id, userId);
    return this.prisma.playlist.delete({ where: { id } });
  }

  @Post("playlist/:id/add-audio")
  async addAudio(
    @Req() request: Request,
    @Param("id") playlistId: string,
    @Body() dto: PlaylistAudioDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    await this.ensurePlaylistOwner(playlistId, userId);
    return this.prisma.playlistItem.create({
      data: {
        playlistId,
        audioId: dto.audioId,
        orderIndex: dto.orderIndex ?? 0,
      },
    });
  }

  @Post("playlist/:id/remove-audio")
  async removeAudio(
    @Req() request: Request,
    @Param("id") playlistId: string,
    @Body() dto: PlaylistAudioDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    await this.ensurePlaylistOwner(playlistId, userId);
    return this.prisma.playlistItem.deleteMany({
      where: { playlistId, audioId: dto.audioId },
    });
  }

  @Post("favorites")
  async favorite(@Req() request: Request, @Body() dto: FavoriteDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.favorite.upsert({
      where: {
        userId_type_contentId: {
          userId,
          type: dto.type,
          contentId: dto.contentId,
        },
      },
      update: {},
      create: { userId, type: dto.type, contentId: dto.contentId },
    });
  }

  @Get("favorites")
  async favorites(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.favorite.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
    });
  }

  @Get("me/downloads")
  async downloads(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.userDownload.findMany({
      where: { userId },
      orderBy: [{ mediaType: "asc" }, { updatedAt: "desc" }],
    });
  }

  @Post("me/downloads")
  async saveDownload(@Req() request: Request, @Body() dto: UserDownloadDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.userDownload.upsert({
      where: { userId_mediaKey: { userId, mediaKey: dto.mediaKey } },
      update: {
        mediaType: dto.mediaType,
        contentId: dto.contentId,
        title: dto.title,
        url: dto.url,
        thumbnailUrl: dto.thumbnailUrl || null,
      },
      create: {
        userId,
        mediaKey: dto.mediaKey,
        mediaType: dto.mediaType,
        contentId: dto.contentId,
        title: dto.title,
        url: dto.url,
        thumbnailUrl: dto.thumbnailUrl || null,
      },
    });
  }

  @Delete("me/downloads/:mediaType/:contentId")
  async deleteDownload(
    @Req() request: Request,
    @Param("mediaType") mediaType: string,
    @Param("contentId") contentId: string,
  ) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.userDownload.deleteMany({
      where: { userId, mediaKey: `${mediaType}:${contentId}` },
    });
  }

  @Post("history")
  async history(@Req() request: Request, @Body() dto: HistoryDto) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.history.create({ data: { userId, videoId: dto.videoId } });
  }

  @Post("audio-progress")
  async progress(
    @Req() request: Request,
    @Body() dto: AudioProgressDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.audioProgress.upsert({
      where: { userId_audioId: { userId, audioId: dto.audioId } },
      update: { lastPosition: dto.lastPosition },
      create: { userId, audioId: dto.audioId, lastPosition: dto.lastPosition },
    });
  }

  @Get("me/scripture-reminders")
  async scriptureReminders(@Req() request: Request) {
    const userId = await this.userIdFromRequest(request);
    return this.prisma.scriptureReminder.findMany({
      where: { userId },
      orderBy: { timeOfDay: "asc" },
      include: {
        scripture: {
          select: {
            id: true,
            title: true,
            description: true,
            backgroundImageUrl: true,
            lines: {
              orderBy: { orderIndex: "asc" },
              select: { content: true, startTime: true },
            },
          },
        },
      },
    });
  }

  @Post("me/scripture-reminders")
  async createScriptureReminder(
    @Req() request: Request,
    @Body() dto: ScriptureReminderDto,
  ) {
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
      include: {
        scripture: {
          select: {
            id: true,
            title: true,
            description: true,
            backgroundImageUrl: true,
            lines: {
              orderBy: { orderIndex: "asc" },
              select: { content: true, startTime: true },
            },
          },
        },
      },
    });
  }

  @Patch("me/scripture-reminders/:id")
  async updateScriptureReminder(
    @Req() request: Request,
    @Param("id") id: string,
    @Body() dto: UpdateScriptureReminderDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    const existing = await this.prisma.scriptureReminder.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException("Không tìm thấy lịch nhắc");
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
      include: {
        scripture: {
          select: {
            id: true,
            title: true,
            description: true,
            backgroundImageUrl: true,
            lines: {
              orderBy: { orderIndex: "asc" },
              select: { content: true, startTime: true },
            },
          },
        },
      },
    });
  }

  @Delete("me/scripture-reminders/:id")
  async deleteScriptureReminder(
    @Req() request: Request,
    @Param("id") id: string,
  ) {
    const userId = await this.userIdFromRequest(request);
    const existing = await this.prisma.scriptureReminder.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException("Không tìm thấy lịch nhắc");
    return this.prisma.scriptureReminder.delete({ where: { id } });
  }

  @Get("me/scripture-reading-preferences")
  async scriptureReadingPreferences(
    @Req() request: Request,
    @Query("scriptureId") scriptureId?: string,
  ) {
    const userId = await this.userIdFromRequest(request);
    const keys = ["global"];
    if (scriptureId?.trim())
      keys.push(this.scripturePreferenceKey(scriptureId));

    const preferences = await this.prisma.scriptureReadingPreference.findMany({
      where: { userId, preferenceKey: { in: keys } },
      orderBy: { updatedAt: "desc" },
    });
    const global =
      preferences.find((item) => item.preferenceKey === "global") ?? null;
    const scripture = scriptureId?.trim()
      ? (preferences.find(
          (item) =>
            item.preferenceKey === this.scripturePreferenceKey(scriptureId),
        ) ?? null)
      : null;

    return {
      global: global ? this.serializeScripturePreference(global) : null,
      scripture: scripture
        ? this.serializeScripturePreference(scripture)
        : null,
      effective: this.serializeScripturePreference(scripture ?? global),
    };
  }

  @Post("me/scripture-reading-preferences")
  async saveScriptureReadingPreference(
    @Req() request: Request,
    @Body() dto: ScriptureReadingPreferenceDto,
  ) {
    const userId = await this.userIdFromRequest(request);
    const scriptureId =
      dto.scope === "SCRIPTURE" ? dto.scriptureId?.trim() : undefined;
    if (dto.scope === "SCRIPTURE" && !scriptureId) {
      throw new BadRequestException(
        "Vui lòng chọn bộ kinh để lưu tốc độ riêng",
      );
    }
    if (scriptureId) {
      const scripture = await this.prisma.scripture.findUnique({
        where: { id: scriptureId },
        select: { id: true },
      });
      if (!scripture) throw new NotFoundException("Không tìm thấy bộ kinh");
    }

    const preferenceKey =
      dto.scope === "GLOBAL"
        ? "global"
        : this.scripturePreferenceKey(scriptureId!);
    const preference = await this.prisma.scriptureReadingPreference.upsert({
      where: { userId_preferenceKey: { userId, preferenceKey } },
      update: {
        scriptureId: scriptureId ?? null,
        speed: dto.speed,
        speedMode: dto.speedMode,
      },
      create: {
        userId,
        preferenceKey,
        scriptureId: scriptureId ?? null,
        speed: dto.speed,
        speedMode: dto.speedMode,
      },
    });
    return this.serializeScripturePreference(preference);
  }

  @Post("feedback")
  async feedback(@Req() request: Request, @Body() dto: FeedbackDto) {
    const userId = await this.optionalUserIdFromRequest(request);
    const message = dto.content.trim();
    if (!message) throw new BadRequestException("Nội dung góp ý không được để trống");
    const content = userId
      ? message
      : JSON.stringify({
          source: "guest",
          name: dto.guestName?.trim() || "Khách",
          email: dto.guestEmail?.trim() || "",
          message,
        });
    return this.prisma.feedback.create({
      data: { userId: userId ?? null, content, type: dto.type },
    });
  }

  private scripturePreferenceKey(scriptureId: string) {
    return `scripture:${scriptureId.trim()}`;
  }

  private serializeScripturePreference(
    preference?: {
      preferenceKey: string;
      scriptureId: string | null;
      speed: number;
      speedMode: string;
      updatedAt: Date;
    } | null,
  ) {
    if (!preference) return null;
    return {
      scope: preference.preferenceKey === "global" ? "GLOBAL" : "SCRIPTURE",
      scriptureId: preference.scriptureId,
      speed: preference.speed,
      speedMode: preference.speedMode,
      updatedAt: preference.updatedAt,
    };
  }
}
