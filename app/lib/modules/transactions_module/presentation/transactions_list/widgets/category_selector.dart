import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/transaction.dart';
import '../transactions_list_cubit.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    required this.transaction,
    required this.categories,
    super.key,
  });

  final Transaction transaction;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Category>(
      tooltip: 'Categorizar',
      onSelected: (category) => context
          .read<TransactionsListCubit>()
          .categorize(transaction.id, category.id),
      itemBuilder: (context) => [
        for (final category in categories)
          PopupMenuItem<Category>(value: category, child: Text(category.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.ganza.elevatedSurface,
          borderRadius: AppRadii.borderSm,
          border: Border.all(color: context.ganza.outline),
        ),
        child: Text(
          transaction.categoryName ?? 'Sem categoria',
          style: context.texts.bodySmall,
        ),
      ),
    );
  }
}
