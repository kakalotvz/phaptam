import { BadRequestException, Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import { AdminAuthGuard } from '../auth/admin.guard';
import { R2Service } from '../storage/r2.service';

class PresignedUrlDto {
  @IsIn([
    'audio',
    'audio/library',
    'audio/scripture',
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
    | 'audio/scripture'
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
}

@Controller('upload')
export class UploadController {
  constructor(private readonly r2: R2Service) {}

  @Post('presigned-url')
  @UseGuards(AdminAuthGuard)
  presignedUrl(@Body() dto: PresignedUrlDto) {
    if (!isSupportedUpload(dto.kind, dto.contentType)) {
      throw new BadRequestException('Unsupported MIME type');
    }
    return this.r2.createPresignedPutUrl(dto.kind, dto.contentType);
  }
}

const supportedAudioTypes = [
  'audio/mpeg',
  'audio/mp3',
  'audio/mp4',
  'audio/x-m4a',
  'audio/aac',
  'audio/ogg',
  'application/ogg',
  'audio/webm',
  'audio/wav',
  'audio/x-wav',
  'audio/flac',
  'audio/x-flac',
];

function isSupportedUpload(kind: PresignedUrlDto['kind'], contentType: string) {
  if (kind.startsWith('audio/')) {
    return contentType.startsWith('audio/') || contentType === 'application/ogg';
  }
  if (kind === 'audio') return supportedAudioTypes.includes(contentType);
  if (kind.startsWith('video')) return contentType === 'video/mp4';
  if (kind.startsWith('images')) return contentType === 'image/webp';
  return false;
}
