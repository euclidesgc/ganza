import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../account_cubit.dart';
import 'account_form.dart';
import 'account_load_error.dart';

class AccountBody extends StatelessWidget {
  const AccountBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) => switch (state) {
        AccountLoading() => const Center(child: CircularProgressIndicator()),
        AccountLoadFailed(:final failure) => AccountLoadError(
          message: failure.message,
        ),
        AccountReady() ||
        AccountSaving() ||
        AccountSaveFailed() => const AccountForm(),
      },
    );
  }
}
