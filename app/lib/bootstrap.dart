import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/observability/app_bloc_observer.dart';
import 'injection.dart';

/// As quatro redes de erro: sem elas, uma exceção fora do build some sem
/// deixar rastro e o app fica "estranho" em vez de quebrar de forma visível.
Future<void> bootstrap(AppConfig config) async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (detalhes) {
        log(
          'FlutterError',
          error: detalhes.exception,
          stackTrace: detalhes.stack,
        );
      };

      PlatformDispatcher.instance.onError = (erro, stackTrace) {
        log('PlatformDispatcher', error: erro, stackTrace: stackTrace);
        return true;
      };

      Bloc.observer = const AppBlocObserver();

      if (!config.isComplete) {
        throw StateError(
          'Configuração incompleta. Rode com '
          '--dart-define-from-file=config/<ambiente>.json',
        );
      }

      // `publishableKey` é o nome novo do mesmo parâmetro; o self-hosted
      // continua entregando a anon key em formato JWT.
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );

      registerDependencies(config);

      runApp(const GanzaApp());
    },
    (erro, stackTrace) =>
        log('runZonedGuarded', error: erro, stackTrace: stackTrace),
  );
}
