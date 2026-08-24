import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/chat_repository_impl.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/usecases/ingest_message.dart';
import 'presentation/chat/chat_cubit.dart';

void registerChatModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => IngestMessage(getIt<ChatRepository>()))
    ..registerFactory(() => ChatCubit(getIt<IngestMessage>()));
}
