import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { Env, validateEnv } from './config/env';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),
    DatabaseModule,
    HealthModule,
  ],
  providers: [
    {
      provide: 'ENV',
      useFactory: (): Env => validateEnv(process.env),
    },
  ],
  exports: ['ENV'],
})
export class AppModule {}
