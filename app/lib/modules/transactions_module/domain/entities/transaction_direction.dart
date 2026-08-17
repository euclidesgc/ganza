enum TransactionDirection {
  incoming('in'),
  outgoing('out');

  const TransactionDirection(this.wireValue);

  final String wireValue;
}
