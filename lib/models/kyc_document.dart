class KycDocument {
  final int     id;
  final String  documentType;
  final String? side;
  final String? documentNumber;
  final String? cardNumber;
  final String  status;
  final String? notes;
  final String? issueDate;
  final String? expiryDate;
  final DateTime createdAt;

  const KycDocument({
    required this.id,
    required this.documentType,
    this.side,
    this.documentNumber,
    this.cardNumber,
    required this.status,
    this.notes,
    this.issueDate,
    this.expiryDate,
    required this.createdAt,
  });

  factory KycDocument.fromJson(Map<String, dynamic> j) => KycDocument(
    id:             j['id'],
    documentType:   j['document_type'],
    side:           j['side'],
    documentNumber: j['document_number'],
    cardNumber:     j['card_number'],
    status:         j['status'] ?? 'Pending',
    notes:          j['notes'],
    issueDate:      j['issue_date'],
    expiryDate:     j['expiry_date'],
    createdAt:      DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  bool get isVerified => status == 'Verified';
  bool get isRejected => status == 'Rejected';
  bool get isPending  => status == 'Pending';
}
