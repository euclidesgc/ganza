import { ServiceUnavailableException } from '@nestjs/common';

import { DatabaseService } from '../database/database.service';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  function comBanco(alcancavel: boolean): HealthController {
    const database = {
      isReachable: jest.fn().mockResolvedValue(alcancavel),
    } as unknown as DatabaseService;
    return new HealthController(database);
  }

  it('responde ok quando o banco responde', async () => {
    await expect(comBanco(true).check()).resolves.toEqual({
      status: 'ok',
      database: 'reachable',
    });
  });

  // O Coolify usa este endpoint como healthcheck: responder 200 com o banco
  // fora deixaria um contêiner "saudável" que não serve para nada.
  it('falha quando o banco não responde', async () => {
    await expect(comBanco(false).check()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
