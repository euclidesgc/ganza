import 'package:intl/intl.dart';

/// A forma abreviada padrão do `intl` para pt-BR carrega ponto ("sex."); a
/// forma falada sem pontuação é o nome completo menos esse sufixo.
const _weekdaySuffix = '-feira';

/// Sempre explícita — nunca "hoje"/"ontem" — para que a data não mude de
/// leitura conforme o momento em que a lista é aberta.
///
/// A transação trafega e é guardada em UTC (`occurredAt.toUtc()` no model);
/// quem lê a tela vive no fuso local. Converter aqui, na borda do
/// formatador, garante que todo chamador ganhe o dia — e o dia-da-semana —
/// que o usuário realmente viveu, sem depender de cada tela lembrar de
/// converter antes de chamar.
String formatTransactionDate(DateTime date, {DateTime? now}) {
  final localDate = date.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final pattern = localDate.year == reference.year ? 'dd/MM' : 'dd/MM/y';

  final dayMonth = DateFormat(pattern, 'pt_BR').format(localDate);
  final weekday = DateFormat(
    'EEEE',
    'pt_BR',
  ).format(localDate).replaceFirst(_weekdaySuffix, '');

  return '$dayMonth, $weekday';
}
