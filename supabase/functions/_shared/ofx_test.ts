import { assertEquals } from '@std/assert';
import { parseOfx } from './ofx.ts';

const OFX_XML = [
  '<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>',
  '<STMTTRN><TRNTYPE>DEBIT</TRNTYPE><DTPOSTED>20260824</DTPOSTED><TRNAMT>-45.00</TRNAMT><FITID>abc123</FITID><MEMO>almoço</MEMO></STMTTRN>',
  '<STMTTRN><TRNTYPE>CREDIT</TRNTYPE><DTPOSTED>20260825</DTPOSTED><TRNAMT>1000.00</TRNAMT><FITID>def456</FITID></STMTTRN>',
  '</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>',
].join('\n');

Deno.test('extrai múltiplos STMTTRN do XML', () => {
  const result = parseOfx(OFX_XML);
  assertEquals(result.length, 2);
  assertEquals(result[0].fitId, 'abc123');
  assertEquals(result[1].fitId, 'def456');
});

Deno.test('normaliza a data e converte o valor para centavos com sinal', () => {
  const result = parseOfx(OFX_XML);
  assertEquals(result[0].postedDate, '2026-08-24');
  assertEquals(result[0].amountCents, -4500);
  assertEquals(result[0].memo, 'almoço');
  assertEquals(result[1].amountCents, 100000);
});

Deno.test('entende SGML 1.x (tags sem fechar)', () => {
  const sgml = '<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260824<TRNAMT>-12.50<FITID>xyz789<MEMO>café';
  const result = parseOfx(sgml);
  assertEquals(result.length, 1);
  assertEquals(result[0].fitId, 'xyz789');
  assertEquals(result[0].postedDate, '2026-08-24');
  assertEquals(result[0].amountCents, -1250);
});

Deno.test('ignora bloco sem FITID, data ou valor', () => {
  const semValor = '<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260824<FITID>a1';
  const result = parseOfx(semValor);
  assertEquals(result.length, 0);
});
