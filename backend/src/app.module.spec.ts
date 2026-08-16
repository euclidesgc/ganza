import { Test } from '@nestjs/testing';

import { AppModule } from './app.module';
import { DatabaseService } from './database/database.service';
import { HealthController } from './health/health.controller';

// Este teste existe por causa de uma falha real: o CI passou verde e o
// contêiner quebrou no boot, porque `ENV` estava declarado no AppModule e o
// DatabaseModule não o enxergava. Testar as peças isoladas não prova que a
// árvore de DI monta — só montá-la prova.
describe('AppModule', () => {
  const envAnterior = process.env;

  beforeEach(() => {
    process.env = {
      ...envAnterior,
      DATABASE_URL: 'postgres://u:p@host:5432/postgres',
      CORS_ORIGINS: 'http://localhost:8080',
      PORT: '3333',
    };
  });

  afterEach(async () => {
    process.env = envAnterior;
  });

  it('monta o contêiner de DI inteiro', async () => {
    const modulo = await Test.createTestingModule({ imports: [AppModule] }).compile();

    expect(modulo.get(HealthController)).toBeInstanceOf(HealthController);
    expect(modulo.get(DatabaseService)).toBeInstanceOf(DatabaseService);

    await modulo.close();
  });
});
