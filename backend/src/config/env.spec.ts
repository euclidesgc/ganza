import { validateEnv } from './env';

describe('validateEnv', () => {
  const completo = {
    DATABASE_URL: 'postgres://u:p@host:5432/postgres',
    CORS_ORIGINS: 'http://localhost:8080',
    PORT: '3333',
  };

  it('aceita um ambiente completo e converte a porta para número', () => {
    const env = validateEnv(completo);
    expect(env.PORT).toBe(3333);
    expect(typeof env.PORT).toBe('number');
  });

  it('usa 3333 quando a porta não é informada', () => {
    const { PORT: _PORT, ...semPorta } = completo;
    expect(validateEnv(semPorta).PORT).toBe(3333);
  });

  // Subir com env faltando produz um serviço que responde e falha na primeira
  // requisição real — o erro aparece longe da causa.
  it.each(['DATABASE_URL', 'CORS_ORIGINS'])('recusa subir sem %s', (chave) => {
    const incompleto = { ...completo, [chave]: '' };
    expect(() => validateEnv(incompleto)).toThrow(/Configuração inválida/);
  });

  it('recusa porta fora da faixa válida', () => {
    expect(() => validateEnv({ ...completo, PORT: '99999' })).toThrow();
  });
});
