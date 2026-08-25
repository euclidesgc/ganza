import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class AudioRecording extends Equatable {
  const AudioRecording({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  @override
  List<Object?> get props => [bytes, mimeType];
}
