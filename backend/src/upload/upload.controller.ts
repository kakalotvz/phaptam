import { BadRequestException, Body, Controller, Post } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import { R2Service } from '../storage/r2.service';

class PresignedUrlDto {
  @IsIn(['audio', 'video', 'images/audio', 'images/video', 'images/banner', 'images/quote', 'images/news'])
  kind!: 'audio' | 'video' | 'images/audio' | 'images/video' | 'images/banner' | 'images/quote' | 'images/news';

  @IsString()
  contentType!: string;
}

@Controller('upload')
export class UploadController {
  constructor(private readonly r2: R2Service) {}

  @Post('presigned-url')
  presignedUrl(@Body() dto: PresignedUrlDto) {
    if (!['audio/mpeg', 'video/mp4', 'image/webp'].includes(dto.contentType)) {
      throw new BadRequestException('Unsupported MIME type');
    }
    return this.r2.createPresignedPutUrl(dto.kind, dto.contentType);
  }
}
