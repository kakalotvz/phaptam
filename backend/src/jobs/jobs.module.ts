import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { ImageProcessor } from './image.processor';
import { RssProcessor } from './rss.processor';

@Module({
  imports: [
    StorageModule,
    BullModule.registerQueue({ name: 'rss' }),
    BullModule.registerQueue({ name: 'image' }),
    BullModule.registerQueue({ name: 'cache' }),
  ],
  providers: [RssProcessor, ImageProcessor],
})
export class JobsModule {}
