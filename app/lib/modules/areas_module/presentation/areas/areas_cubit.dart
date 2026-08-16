import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/area.dart';
import '../../domain/usecases/list_active_areas.dart';

part 'areas_state.dart';

class AreasCubit extends Cubit<AreasState> {
  AreasCubit(this._listActiveAreas) : super(const AreasLoading());

  final ListActiveAreas _listActiveAreas;

  Future<void> load() async {
    emit(const AreasLoading());

    final result = await _listActiveAreas();
    if (isClosed) return;

    emit(
      result.fold(
        (failure) => AreasLoadFailed(failure),
        (areas) => areas.isEmpty ? const AreasEmpty() : AreasLoaded(areas),
      ),
    );
  }
}
