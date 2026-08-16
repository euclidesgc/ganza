import { plainToInstance } from 'class-transformer';
import { IsInt, IsNotEmpty, IsString, Max, Min, validateSync } from 'class-validator';

export class Env {
  @IsString()
  @IsNotEmpty()
  DATABASE_URL!: string;

  @IsString()
  @IsNotEmpty()
  CORS_ORIGINS!: string;

  @IsInt()
  @Min(1)
  @Max(65535)
  PORT!: number;
}

// Subir com env faltando produz um serviço que responde e falha na primeira
// requisição real. Falhar no boot é mais barato de diagnosticar.
export function validateEnv(raw: Record<string, unknown>): Env {
  const env = plainToInstance(Env, { ...raw, PORT: Number(raw.PORT ?? 3333) });
  const errors = validateSync(env, { skipMissingProperties: false });

  if (errors.length > 0) {
    const detalhe = errors.map((e) => e.property).join(', ');
    throw new Error(`Configuração inválida ou ausente: ${detalhe}`);
  }

  return env;
}
