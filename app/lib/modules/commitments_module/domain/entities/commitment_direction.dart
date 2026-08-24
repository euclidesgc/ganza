enum CommitmentDirection {
  incoming('in'),
  outgoing('out');

  const CommitmentDirection(this.wireValue);

  final String wireValue;

  static CommitmentDirection? fromWire(String value) {
    for (final direction in values) {
      if (direction.wireValue == value) return direction;
    }
    return null;
  }
}
