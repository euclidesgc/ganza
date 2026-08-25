import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/theme.dart';
import '../../../domain/entities/new_transaction.dart';
import '../../../domain/entities/transaction_direction.dart';
import '../new_transaction_cubit.dart';
import 'amount_field.dart';
import 'description_field.dart';
import 'direction_selector.dart';
import 'new_transaction_error_banner.dart';
import 'occurred_at_field.dart';
import 'register_button.dart';

class NewTransactionForm extends StatefulWidget {
  const NewTransactionForm({super.key, this.initialDirection});

  final TransactionDirection? initialDirection;

  @override
  State<NewTransactionForm> createState() => _NewTransactionFormState();
}

class _NewTransactionFormState extends State<NewTransactionForm> {
  final _descriptionController = TextEditingController();
  late final _direction = ValueNotifier(
    widget.initialDirection ?? TransactionDirection.outgoing,
  );
  final _occurredAt = ValueNotifier(DateTime.now());
  final _isValid = ValueNotifier(false);

  var _amountCents = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _direction.dispose();
    _occurredAt.dispose();
    _isValid.dispose();
    super.dispose();
  }

  void _revalidate() {
    _isValid.value =
        _amountCents > 0 && _descriptionController.text.trim().isNotEmpty;
  }

  void _submit(BuildContext context) {
    final chosenDate = _occurredAt.value;
    final occurredAt = DateTime(
      chosenDate.year,
      chosenDate.month,
      chosenDate.day,
      12,
    );

    context.read<NewTransactionCubit>().submit(
      NewTransaction(
        direction: _direction.value,
        amount: _amountCents,
        description: _descriptionController.text.trim(),
        occurredAt: occurredAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NewTransactionCubit, NewTransactionState>(
      listener: (context, state) {
        if (state is NewTransactionSucceeded) context.pop(true);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<TransactionDirection>(
              valueListenable: _direction,
              builder: (context, direction, _) => DirectionSelector(
                value: direction,
                onChanged: (value) => _direction.value = value,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AmountField(
              onChanged: (cents) {
                _amountCents = cents;
                _revalidate();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DescriptionField(
              controller: _descriptionController,
              onChanged: (_) => _revalidate(),
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<DateTime>(
              valueListenable: _occurredAt,
              builder: (context, occurredAt, _) => OccurredAtField(
                value: occurredAt,
                onChanged: (value) => _occurredAt.value = value,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const NewTransactionErrorBanner(),
            const SizedBox(height: AppSpacing.md),
            RegisterButton(
              isValid: _isValid,
              onPressed: () => _submit(context),
            ),
          ],
        ),
      ),
    );
  }
}
