import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../injection.dart';
import 'areas_cubit.dart';
import 'widgets/areas_body.dart';

class AreasPage extends StatelessWidget {
  const AreasPage({super.key});

  static Widget pageBuilder(BuildContext context, GoRouterState state) =>
      BlocProvider(
        create: (_) => getIt<AreasCubit>()..load(),
        child: const AreasPage(),
      );

  @override
  Widget build(BuildContext context) => const AreasBody();
}
