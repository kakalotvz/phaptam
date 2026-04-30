import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ImageProcessor } from './image.processor';
import { RssProcessor } from './rss.processor';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'rss' }),
    BullModule.registerQueue({ name: 'image' }),
    BullModule.registerQueue({ name: 'cache' }),
  ],
  providers: [RssProcessor, ImageProcessor],
})
export class JobsModule {}
