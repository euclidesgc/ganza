import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/core/theme/app_theme.dart';
import 'package:ganza/modules/transactions_module/domain/entities/new_transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction.dart';
import 'package:ganza/modules/transactions_module/domain/entities/transaction_direction.dart';
import 'package:ganza/modules/transactions_module/domain/usecases/create_transaction.dart';
import 'package:ganza/modules/transactions_module/presentation/new_transaction/new_transaction_cubit.dart';
import 'package:ganza/modules/transactions_module/presentation/new_transaction/widgets/new_transaction_form.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateTransaction extends Mock implements CreateTransaction {}

void main() {
  late MockCreateTransaction createTransaction;
  late NewTransactionCubit cubit;

  final newTransaction = NewTransaction(
    direction: TransactionDirection.outgoing,
    amount: 4500,
    description: 'Almoço',
    occurredAt: DateTime(2026, 8, 15),
  );

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    createTransaction = MockCreateTransaction();
    cubit = NewTransactionCubit(createTransaction);
  });

  Widget formWith(NewTransactionCubit cubit) => MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<NewTransactionCubit>.value(
      value: cubit,
      child: const Scaffold(body: NewTransactionForm()),
    ),
  );

  testWidgets('botão Registrar desabilitado com formulário vazio', (
    tester,
  ) async {
    await tester.pumpWidget(formWith(cubit));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Registrar'), findsOneWidget);
  });

  testWidgets('botão desabilitado e rótulo Registrando… durante o envio', (
    tester,
  ) async {
    when(
      () => createTransaction.call(newTransaction),
    ).thenAnswer((_) => Completer<Either<Failure, Transaction>>().future);

    await tester.pumpWidget(formWith(cubit));
    cubit.submit(newTransaction);
    await tester.pump();

    expect(find.text('Registrando…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('falha mostra o banner com a mensagem da Failure', (
    tester,
  ) async {
    const failure = NetworkFailure();
    when(
      () => createTransaction.call(newTransaction),
    ).thenAnswer((_) async => const Left(failure));

    await tester.pumpWidget(formWith(cubit));
    cubit.submit(newTransaction);
    await tester.pump();
    await tester.pump();

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
  });
}
