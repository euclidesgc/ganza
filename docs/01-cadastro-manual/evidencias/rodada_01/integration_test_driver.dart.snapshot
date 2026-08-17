// Driver de host do E2E — INSTRUMENTAÇÃO TEMPORÁRIA (sai no wrap).
//
// Roda na máquina, não no emulador: é aqui que os bytes de
// `binding.takeScreenshot(nome)` viram arquivo. O destino vem do ambiente
// para que `e2e_shots.sh` decida a pasta da rodada sem recompilar nada.

import 'dart:io';

// `integration_test_driver.dart` (o comum) não tem `onScreenshot`; quem tem é
// a variante `_extended`.
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot:
      (String nome, List<int> bytes, [Map<String, Object?>? argumentos]) async {
        final destino = Platform.environment['E2E_DESTINO'];
        if (destino == null || destino.isEmpty) {
          stderr.writeln('E2E_DESTINO não definido — print descartado.');
          return false;
        }

        final arquivo = File('$destino/$nome.png');
        await arquivo.parent.create(recursive: true);
        await arquivo.writeAsBytes(bytes);
        stdout.writeln('print salvo: ${arquivo.path} (${bytes.length} bytes)');
        return true;
      },
);
