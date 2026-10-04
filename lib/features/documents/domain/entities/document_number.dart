class DocumentNumber {
  const DocumentNumber({
    required this.documentType,
    required this.year,
    required this.sequence,
    required this.value,
  });
  final String documentType;
  final int year;
  final int sequence;
  final String value;
}
