import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_from_exception.dart';
import '../../domain/entities/new_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../models/transaction_model.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  const TransactionsRepositoryImpl(this._client);

  final SupabaseClient _client;

  /// Sem filtro por usuário na query: quem decide o que este usuário enxerga é
  /// a RLS. Replicar a regra aqui daria a impressão de proteção e criaria dois
  /// lugares para errar.
  @override
  Future<Either<Failure, List<Transaction>>> list() async {
    try {
      final rows = await _client
          .from('transactions')
          .select(
            'id, area_id, direction, amount, description, occurred_at, '
            'source, reconciliation_status, created_at, updated_at',
          )
          .order('occurred_at', ascending: false)
          .order('created_at', ascending: false);

      final transactions = <Transaction>[];
      for (final row in rows) {
        final parsed = TransactionModel.fromMap(row);
        if (parsed.isLeft()) {
          return parsed.map((transaction) => <Transaction>[transaction]);
        }
        transactions.add(
          parsed.getOrElse((_) => throw StateError('inalcançável')),
        );
      }
      return Right(transactions);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }

  /// A Edge Function decide direção, valor e conciliação; o `Dio` de
  /// `core/network` aponta para outro deployável e não serve aqui. O
  /// `FunctionsClient` injeta `apikey` e `Authorization` com a mesma sessão
  /// usada em `list`.
  @override
  Future<Either<Failure, Transaction>> create(
    NewTransaction transaction,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'transactions',
        body: TransactionModel.toPayload(transaction),
      );
      return TransactionModel.fromMap(response.data as Map<String, dynamic>);
    } catch (error) {
      return Left(failureFromException(error));
    }
  }
}
