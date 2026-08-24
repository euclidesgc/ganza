import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/repositories/chat_repository_impl.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/usecases/cancel_proposal.dart';
import 'domain/usecases/confirm_proposal.dart';
import 'domain/usecases/ingest_message.dart';
import 'domain/usecases/list_pending_proposals.dart';
import 'presentation/chat/chat_cubit.dart';

void registerChatModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(getIt<SupabaseClient>()),
    )
    ..registerFactory(() => IngestMessage(getIt<ChatRepository>()))
    ..registerFactory(() => ListPendingProposals(getIt<ChatRepository>()))
    ..registerFactory(() => ConfirmProposal(getIt<ChatRepository>()))
    ..registerFactory(() => CancelProposal(getIt<ChatRepository>()))
    ..registerFactory(
      () => ChatCubit(
        getIt<IngestMessage>(),
        getIt<ListPendingProposals>(),
        getIt<ConfirmProposal>(),
        getIt<CancelProposal>(),
      ),
    );
}
