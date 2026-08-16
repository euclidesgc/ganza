import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { DatabaseService } from '../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly database: DatabaseService) {}

  // O Coolify usa este endpoint como healthcheck. Responder 200 sem checar o
  // banco deixaria um contêiner "saudável" que não serve para nada.
  @Get()
  async check(): Promise<{ status: string; database: string }> {
    const reachable = await this.database.isReachable();

    if (!reachable) {
      throw new ServiceUnavailableException({
        status: 'degraded',
        database: 'unreachable',
      });
    }

    return { status: 'ok', database: 'reachable' };
  }
}
