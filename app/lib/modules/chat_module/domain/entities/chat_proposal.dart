import 'package:equatable/equatable.dart';

class ChatProposal extends Equatable {
  const ChatProposal({required this.kind, required this.payload});

  final String kind;
  final Map<String, dynamic> payload;

  String get description => payload['description'] as String? ?? '';

  @override
  List<Object?> get props => [kind, payload];
}
