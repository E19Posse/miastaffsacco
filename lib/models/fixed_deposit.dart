class FixedDeposit {
  final int     id;
  final String  fdNumber;
  final String  productName;
  final double  principal;
  final double  interestRate;
  final double  accruedInterest;
  final DateTime? startDate;
  final DateTime? maturityDate;
  final String  status;
  final bool    autoRollover;
  final String? interestMode;

  const FixedDeposit({
    required this.id,
    required this.fdNumber,
    required this.productName,
    required this.principal,
    required this.interestRate,
    required this.accruedInterest,
    this.startDate,
    this.maturityDate,
    required this.status,
    required this.autoRollover,
    this.interestMode,
  });

  factory FixedDeposit.fromJson(Map<String, dynamic> j) => FixedDeposit(
    id:              j['id'] as int,
    fdNumber:        j['fd_number'] as String,
    productName:     j['product_name'] as String? ?? 'Fixed Deposit',
    principal:       (j['principal'] as num).toDouble(),
    interestRate:    (j['interest_rate'] as num).toDouble(),
    accruedInterest: (j['accrued_interest'] as num).toDouble(),
    startDate:       j['start_date'] != null ? DateTime.tryParse(j['start_date']) : null,
    maturityDate:    j['maturity_date'] != null ? DateTime.tryParse(j['maturity_date']) : null,
    status:          j['status'] as String? ?? 'Active',
    autoRollover:    j['auto_rollover'] as bool? ?? false,
    interestMode:    j['interest_mode'] as String?,
  );

  bool get isMatured => maturityDate != null && DateTime.now().isAfter(maturityDate!);
}
