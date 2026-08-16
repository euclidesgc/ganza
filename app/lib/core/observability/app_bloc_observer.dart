import 'dart:developer';

import 'package:bloc/bloc.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('${bloc.runtimeType} falhou', error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
