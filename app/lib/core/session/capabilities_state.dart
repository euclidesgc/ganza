part of 'capabilities_cubit.dart';

sealed class CapabilitiesState extends Equatable {
  const CapabilitiesState(this.capabilities);

  final UserCapabilities capabilities;

  @override
  List<Object?> get props => [capabilities];
}

final class CapabilitiesUnresolved extends CapabilitiesState {
  const CapabilitiesUnresolved() : super(const UserCapabilities.unresolved());
}

final class CapabilitiesLoaded extends CapabilitiesState {
  const CapabilitiesLoaded(super.capabilities);
}
