part of 'new_transaction_cubit.dart';

sealed class NewTransactionState extends Equatable {
  const NewTransactionState();

  @override
  List<Object?> get props => [];
}

final class NewTransactionIdle extends NewTransactionState {
  const NewTransactionIdle();
}

final class NewTransactionSubmitting extends NewTransactionState {
  const NewTransactionSubmitting();
}

final class NewTransactionSucceeded extends NewTransactionState {
  const NewTransactionSucceeded(this.transaction);

  final Transaction transaction;

  @override
  List<Object?> get props => [transaction];
}

final class NewTransactionFailed extends NewTransactionState {
  const NewTransactionFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
