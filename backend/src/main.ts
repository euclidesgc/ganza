import { Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { validateEnv } from './config/env';

async function bootstrap(): Promise<void> {
  const env = validateEnv(process.env);
  const app = await NestFactory.create(AppModule);

  // `whitelist` + `forbidNonWhitelisted` fazem campo não declarado no DTO
  // virar 400 em vez de atravessar em silêncio até o banco.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: env.CORS_ORIGINS.split(',').map((origem) => origem.trim()),
    credentials: true,
  });

  await app.listen(env.PORT, '0.0.0.0');
  new Logger('bootstrap').log(`ganza-api ouvindo na porta ${env.PORT}`);
}

void bootstrap();
