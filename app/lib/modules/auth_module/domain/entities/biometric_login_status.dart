import 'package:equatable/equatable.dart';

class BiometricLoginStatus extends Equatable {
  const BiometricLoginStatus({
    required this.isSupported,
    required this.isEnabled,
  });

  final bool isSupported;
  final bool isEnabled;

  @override
  List<Object?> get props => [isSupported, isEnabled];
}
