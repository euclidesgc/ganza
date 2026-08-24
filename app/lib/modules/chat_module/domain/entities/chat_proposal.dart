import 'package:equatable/equatable.dart';

class ChatProposal extends Equatable {
  const ChatProposal({
    required this.id,
    required this.kind,
    required this.payload,
    required this.sequence,
    required this.status,
  });

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final int sequence;
  final String status;

  String get description => payload['description'] as String? ?? '';

  @override
  List<Object?> get props => [id, kind, payload, sequence, status];
}
