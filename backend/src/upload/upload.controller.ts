import { BadRequestException, Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { AdminAuthGuard } from '../auth/admin.guard';
import { R2Service } from '../storage/r2.service';

class PresignedUrlDto {
  @IsIn([
    'audio',
    'audio/library',
    'audio/meditation',
    'video',
    'video/dharma',
    'images/audio',
    'images/video',
    'images/banner',
    'images/quote',
    'images/quote-background',
    'images/news',
    'images/scripture',
    'images/meditation',
  ])
  kind!:
    | 'audio'
    | 'audio/library'
    | 'audio/meditation'
    | 'video'
    | 'video/dharma'
    | 'images/audio'
    | 'images/video'
    | 'images/banner'
    | 'images/quote'
    | 'images/quote-background'
    | 'images/news'
    | 'images/scripture'
    | 'images/meditation';

  @IsString()
  contentType!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  sizeBytes?: number;
}

@Controller('upload')
export class UploadController {
  constructor(private readonly r2: R2Service) {}

  @Post('presigned-url')
  @UseGuards(AdminAuthGuard)
  presignedUrl(@Body() dto: PresignedUrlDto) {
    if (!['audio/mpeg', 'video/mp4', 'image/webp'].includes(dto.contentType)) {
      throw new BadRequestException('Unsupported MIME type');
    }
    const limit = uploadLimitBytes(dto.kind);
    if (dto.sizeBytes !== undefined && dto.sizeBytes > limit) {
      throw new BadRequestException(`Tệp vượt quá dung lượng cho phép (${Math.round(limit / 1024 / 1024)} MB)`);
    }
    return this.r2.createPresignedPutUrl(dto.kind, dto.contentType);
  }
}

function uploadLimitBytes(kind: PresignedUrlDto['kind']) {
  if (kind.startsWith('images/')) return 8 * 1024 * 1024;
  if (kind.startsWith('video')) return 1024 * 1024 * 1024;
  return 250 * 1024 * 1024;
}
