enum OccurrenceStatus {
  pending('pending'),
  postponed('postponed'),
  done('done'),
  skipped('skipped'),
  cancelled('cancelled'),
  missed('missed');

  const OccurrenceStatus(this.wireValue);

  final String wireValue;

  static OccurrenceStatus? fromWire(String value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}
