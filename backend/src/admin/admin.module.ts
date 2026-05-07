import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { AdminController } from './admin.controller';

import { AuthModule } from '../auth/auth.module';
import { PresenceModule } from '../presence/presence.module';

@Module({ imports: [StorageModule, AuthModule, PresenceModule], controllers: [AdminController] })
export class AdminModule {}
