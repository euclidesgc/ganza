import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/settings_module/domain/domain.dart';
import 'package:ganza/modules/settings_module/presentation/bank/bank_settings_cubit.dart';
import 'package:ganza/modules/settings_module/presentation/bank/settings_bank_page.dart';
import 'package:ganza/modules/settings_module/presentation/bank/widgets/bank_connect_button.dart';
import 'package:ganza/modules/settings_module/presentation/bank/widgets/bank_disconnect_button.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetBankConnection extends Mock implements GetBankConnection {}

class _MockStartBankConnection extends Mock implements StartBankConnection {}

class _MockDisconnectBankConnection extends Mock
    implements DisconnectBankConnection {}

void main() {
  late _MockGetBankConnection getConnection;
  late _MockStartBankConnection startConnection;
  late _MockDisconnectBankConnection disconnectConnection;

  const pendingConnection = BankConnection(
    id: 'c1',
    institution: 'Banco Ganzá',
    status: BankConnectionStatus.pending,
    lastSyncedAt: null,
  );

  final connectedConnection = BankConnection(
    id: 'c1',
    institution: 'Banco Ganzá',
    status: BankConnectionStatus.connected,
    lastSyncedAt: DateTime.utc(2026, 8, 15, 12),
  );

  const errorConnection = BankConnection(
    id: 'c1',
    institution: 'Banco Ganzá',
    status: BankConnectionStatus.error,
    lastSyncedAt: null,
  );

  const disconnectedConnection = BankConnection(
    id: 'c1',
    institution: 'Banco Ganzá',
    status: BankConnectionStatus.disconnected,
    lastSyncedAt: null,
  );

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    getConnection = _MockGetBankConnection();
    startConnection = _MockStartBankConnection();
    disconnectConnection = _MockDisconnectBankConnection();
  });

  Widget montar() => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<BankSettingsCubit>(
      create: (_) => BankSettingsCubit(
        getConnection,
        startConnection,
        disconnectConnection,
      )..load(),
      child: const SettingsBankPage(),
    ),
  );

  group('os quatro estados de conexão renderizam rótulo textual distinto', () {
    testWidgets('pendente mostra "Conexão pendente"', (tester) async {
      when(
        () => getConnection(),
      ).thenAnswer((_) async => const Right(pendingConnection));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.text('Conexão pendente'), findsOneWidget);
      expect(find.text('Banco conectado'), findsNothing);
      expect(find.text('Erro na conexão'), findsNothing);
      expect(find.text('Banco desconectado'), findsNothing);
    });

    testWidgets('conectado mostra "Banco conectado"', (tester) async {
      when(
        () => getConnection(),
      ).thenAnswer((_) async => Right(connectedConnection));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.text('Banco conectado'), findsOneWidget);
      expect(find.text('Conexão pendente'), findsNothing);
      expect(find.text('Erro na conexão'), findsNothing);
      expect(find.text('Banco desconectado'), findsNothing);
    });

    testWidgets('erro mostra "Erro na conexão"', (tester) async {
      when(
        () => getConnection(),
      ).thenAnswer((_) async => const Right(errorConnection));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.text('Erro na conexão'), findsOneWidget);
      expect(find.text('Conexão pendente'), findsNothing);
      expect(find.text('Banco conectado'), findsNothing);
      expect(find.text('Banco desconectado'), findsNothing);
    });

    testWidgets('desconectado mostra "Banco desconectado"', (tester) async {
      when(
        () => getConnection(),
      ).thenAnswer((_) async => const Right(disconnectedConnection));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.text('Banco desconectado'), findsOneWidget);
      expect(find.text('Conexão pendente'), findsNothing);
      expect(find.text('Banco conectado'), findsNothing);
      expect(find.text('Erro na conexão'), findsNothing);
    });
  });

  group('desconectar pede confirmação explícita', () {
    setUp(() {
      when(
        () => getConnection(),
      ).thenAnswer((_) async => Right(connectedConnection));
    });

    testWidgets('cancelar não chama a desconexão e mantém o estado conectado', (
      tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.byType(BankDisconnectButton), findsOneWidget);
      await tester.tap(find.byKey(const Key('bank-disconnect-button')));
      await tester.pumpAndSettle();

      expect(find.text('Desconectar banco?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bank-disconnect-confirm-cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => disconnectConnection());
      expect(find.text('Banco conectado'), findsOneWidget);
      expect(find.text('Desconectar banco?'), findsNothing);
    });

    testWidgets('confirmar chama a desconexão', (tester) async {
      when(
        () => disconnectConnection(),
      ).thenAnswer((_) async => const Right(unit));

      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bank-disconnect-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bank-disconnect-confirm-accept')));
      await tester.pumpAndSettle();

      verify(() => disconnectConnection()).called(1);
    });
  });

  testWidgets('sem conexão nenhuma, o botão de ação é o de conectar, não o de '
      'desconectar', (tester) async {
    when(() => getConnection()).thenAnswer((_) async => const Right(null));

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.text('Banco desconectado'), findsOneWidget);
    expect(find.byType(BankConnectButton), findsOneWidget);
    expect(find.byType(BankDisconnectButton), findsNothing);
  });
}
