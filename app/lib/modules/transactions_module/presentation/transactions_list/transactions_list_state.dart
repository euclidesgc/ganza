part of 'transactions_list_cubit.dart';

sealed class TransactionsListState extends Equatable {
  const TransactionsListState();

  @override
  List<Object?> get props => [];
}

final class TransactionsListLoading extends TransactionsListState {
  const TransactionsListLoading();
}

final class TransactionsListLoaded extends TransactionsListState {
  const TransactionsListLoaded(this.transactions, {this.categories = const []});

  final List<Transaction> transactions;
  final List<Category> categories;

  @override
  List<Object?> get props => [transactions, categories];
}

final class TransactionsListEmpty extends TransactionsListState {
  const TransactionsListEmpty();
}

final class TransactionsListLoadFailed extends TransactionsListState {
  const TransactionsListLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
