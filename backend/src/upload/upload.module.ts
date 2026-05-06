import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { StorageModule } from '../storage/storage.module';
import { UploadController } from './upload.controller';

@Module({
  imports: [StorageModule, AuthModule],
  controllers: [UploadController],
})
export class UploadModule {}
