import { Global, Module } from '@nestjs/common';

import { Env, validateEnv } from './env';

// Global e com o provider aqui dentro: declarar `ENV` no AppModule fazia o
// DatabaseModule não enxergá-lo — `@Global()` exporta o que o módulo provê,
// não importa o que outro módulo declarou. O contêiner quebrava no boot, com
// o CI verde, porque nenhum teste montava a árvore de DI.
@Global()
@Module({
  providers: [{ provide: 'ENV', useFactory: (): Env => validateEnv(process.env) }],
  exports: ['ENV'],
})
export class EnvModule {}
