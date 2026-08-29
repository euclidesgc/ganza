// funcao-sem-consumidor-ok: pronta e testada, sem UI ainda — onde entra a
// tela de conciliação é decisão de produto aberta na P9 (docs/decisions.md).
import handler from './handler.ts';

Deno.serve(handler);
