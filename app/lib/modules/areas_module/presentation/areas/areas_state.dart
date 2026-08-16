part of 'areas_cubit.dart';

sealed class AreasState extends Equatable {
  const AreasState();

  @override
  List<Object?> get props => [];
}

final class AreasLoading extends AreasState {
  const AreasLoading();
}

final class AreasLoaded extends AreasState {
  const AreasLoaded(this.areas);

  final List<Area> areas;

  @override
  List<Object?> get props => [areas];
}

/// Distinto de [AreasLoaded] com lista vazia: nenhuma área é sintoma de que o
/// trigger de signup não rodou, não um estado normal do produto.
final class AreasEmpty extends AreasState {
  const AreasEmpty();
}

final class AreasLoadFailed extends AreasState {
  const AreasLoadFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
