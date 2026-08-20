import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/theme/theme.dart';
import '../account_cubit.dart';
import 'account_display_name_field.dart';
import 'account_email_field.dart';
import 'account_failure_banner.dart';
import 'account_save_button.dart';

class AccountForm extends StatefulWidget {
  const AccountForm({super.key});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AccountCubit>().state.profileOrNull;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AccountCubit>().save(displayName: _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocSelector<AccountCubit, AccountState, String>(
            selector: (state) => state.profileOrNull?.email ?? '',
            builder: (context, email) => AccountEmailField(email: email),
          ),
          const SizedBox(height: AppSpacing.md),
          BlocSelector<AccountCubit, AccountState, bool>(
            selector: (state) => state.profileOrNull?.displayName == null,
            builder: (context, semNome) => AccountDisplayNameField(
              controller: _nameController,
              enabled: true,
              hintText: semNome ? 'Ainda não preenchido' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BlocSelector<AccountCubit, AccountState, Failure?>(
            selector: (state) =>
                state is AccountSaveFailed ? state.failure : null,
            builder: (context, failure) =>
                AccountFailureBanner(failure: failure),
          ),
          const SizedBox(height: AppSpacing.md),
          BlocSelector<AccountCubit, AccountState, bool>(
            selector: (state) => state is AccountSaving,
            builder: (context, saving) =>
                AccountSaveButton(saving: saving, onPressed: _save),
          ),
        ],
      ),
    );
  }
}
