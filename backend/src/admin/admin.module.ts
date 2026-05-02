import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { AdminController } from './admin.controller';

@Module({ imports: [StorageModule], controllers: [AdminController] })
export class AdminModule {}
