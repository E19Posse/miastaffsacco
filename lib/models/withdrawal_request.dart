class WithdrawalRequest {
  final int      id;
  final String   type; // 'savings' | 'fd'
  final String   reference;
  final String?  accountOrFdNumber;
  final double?  amount;
  final double?  netPayout;
  final String   method;
  final String   status;
  final String?  memberNotes;
  final String?  wdType;
  final String?  reviewNotes;
  final String?  reviewedBy;
  final DateTime? reviewedAt;
  final String?  processedBy;
  final DateTime? processedAt;
  final DateTime createdAt;

  const WithdrawalRequest({
    required this.id,
    required this.type,
    required this.reference,
    this.accountOrFdNumber,
    this.amount,
    this.netPayout,
    required this.method,
    required this.status,
    this.memberNotes,
    this.wdType,
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.processedBy,
    this.processedAt,
    required this.createdAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> j) => WithdrawalRequest(
    id:                  j['id'] as int,
    type:                j['type'] as String,
    reference:           j['reference'] as String,
    accountOrFdNumber:   (j['account_number'] ?? j['fd_number'])?.toString(),
    amount:              j['amount'] != null ? (j['amount'] as num).toDouble() : null,
    netPayout:           j['net_payout'] != null ? (j['net_payout'] as num).toDouble() : null,
    method:              j['method'] as String? ?? '',
    status:              j['status'] as String? ?? 'pending',
    memberNotes:         j['member_notes'] as String?,
    wdType:              j['wd_type'] as String?,
    reviewNotes:         j['review_notes'] as String?,
    reviewedBy:          j['reviewed_by'] as String?,
    reviewedAt:          j['reviewed_at'] != null ? DateTime.tryParse(j['reviewed_at'].toString()) : null,
    processedBy:         j['processed_by'] as String?,
    processedAt:         j['processed_at'] != null ? DateTime.tryParse(j['processed_at'].toString()) : null,
    createdAt:           DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  bool get isPending   => status == 'pending';
  bool get isApproved  => status == 'approved';
  bool get isCompleted => status == 'completed';
  bool get isRejected  => status == 'rejected';
}
