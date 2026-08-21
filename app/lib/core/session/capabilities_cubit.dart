import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'capabilities_source.dart';
import 'user_capabilities.dart';

part 'capabilities_state.dart';

class CapabilitiesCubit extends Cubit<CapabilitiesState> {
  CapabilitiesCubit(this._source) : super(const CapabilitiesUnresolved());

  final CapabilitiesSource _source;

  Future<void> refresh() async {
    final result = await _source.load();
    if (isClosed) return;

    emit(
      result.fold(
        (_) => const CapabilitiesLoaded(UserCapabilities.unresolved()),
        CapabilitiesLoaded.new,
      ),
    );
  }
}
