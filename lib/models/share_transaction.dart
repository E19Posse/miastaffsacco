class ShareSummary {
  final int    totalUnits;
  final double unitValue;
  final double totalValue;
  final List<ShareTxn> transactions;

  const ShareSummary({
    required this.totalUnits,
    required this.unitValue,
    required this.totalValue,
    required this.transactions,
  });

  factory ShareSummary.fromJson(Map<String, dynamic> j) => ShareSummary(
    totalUnits:   j['total_units'] as int? ?? 0,
    unitValue:    (j['unit_value'] as num?)?.toDouble() ?? 0,
    totalValue:   (j['total_value'] as num?)?.toDouble() ?? 0,
    transactions: (j['transactions'] as List<dynamic>? ?? [])
        .map((e) => ShareTxn.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ShareTxn {
  final int     id;
  final String  reference;
  final String  type;
  final int     units;
  final double  unitValue;
  final double  totalValue;
  final int     balanceAfter;
  final String? certificateNumber;
  final DateTime? date;

  const ShareTxn({
    required this.id,
    required this.reference,
    required this.type,
    required this.units,
    required this.unitValue,
    required this.totalValue,
    required this.balanceAfter,
    this.certificateNumber,
    this.date,
  });

  factory ShareTxn.fromJson(Map<String, dynamic> j) => ShareTxn(
    id:                (j['id'] as num?)?.toInt() ?? 0,
    reference:         j['reference'] as String? ?? '',
    type:              j['type'] as String? ?? 'Purchase',
    units:             j['units'] as int? ?? 0,
    unitValue:         (j['unit_value'] as num?)?.toDouble() ?? 0,
    totalValue:        (j['total_value'] as num?)?.toDouble() ?? 0,
    balanceAfter:      j['balance_after'] as int? ?? 0,
    certificateNumber: j['certificate_number'] as String?,
    date:              j['transaction_date'] != null ? DateTime.tryParse(j['transaction_date']) : null,
  );

  bool get isCredit => type == 'Purchase' || type == 'Transfer In' || type == 'Dividend';
}

class SharePurchaseRequest {
  final int      id;
  final String   reference;
  final int      unitsRequested;
  final double   unitPrice;
  final double   totalAmount;
  final String   paymentMode;
  final String?  notes;
  final String   status;
  final String?  rejectionReason;
  final DateTime createdAt;

  const SharePurchaseRequest({
    required this.id,
    required this.reference,
    required this.unitsRequested,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentMode,
    this.notes,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory SharePurchaseRequest.fromJson(Map<String, dynamic> j) => SharePurchaseRequest(
    id:              j['id'] as int,
    reference:       j['reference'] as String? ?? '',
    unitsRequested:  j['units_requested'] as int? ?? 0,
    unitPrice:       (j['unit_price'] as num?)?.toDouble() ?? 0,
    totalAmount:     (j['total_amount'] as num?)?.toDouble() ?? 0,
    paymentMode:     j['payment_mode'] as String? ?? '',
    notes:           j['notes'] as String?,
    status:          j['status'] as String? ?? 'Pending',
    rejectionReason: j['rejection_reason'] as String?,
    createdAt:       DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
