import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { AdminController } from './admin.controller';

import { AuthModule } from '../auth/auth.module';

@Module({ imports: [StorageModule, AuthModule], controllers: [AdminController] })
export class AdminModule {}
