import 'package:intl/intl.dart';

/// A forma abreviada padrão do `intl` para pt-BR carrega ponto ("sex."); a
/// forma falada sem pontuação é o nome completo menos esse sufixo.
const _weekdaySuffix = '-feira';

/// Sempre explícita — nunca "hoje"/"ontem" — para que a data não mude de
/// leitura conforme o momento em que a lista é aberta.
String formatTransactionDate(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final pattern = date.year == reference.year ? 'dd/MM' : 'dd/MM/y';

  final dayMonth = DateFormat(pattern, 'pt_BR').format(date);
  final weekday = DateFormat(
    'EEEE',
    'pt_BR',
  ).format(date).replaceFirst(_weekdaySuffix, '');

  return '$dayMonth, $weekday';
}
