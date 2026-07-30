class Loan {
  final int      id;
  final String   loanNumber;
  final String   productName;
  final double   principal;
  final double   balance;
  final double   paid;
  final double   interestRate;
  final int      termMonths;
  final String   status;
  final DateTime? createdAt;
  final DateTime? disbursedAt;
  final DateTime? nextDueDate;

  const Loan({
    required this.id,
    required this.loanNumber,
    required this.productName,
    required this.principal,
    required this.balance,
    required this.paid,
    required this.interestRate,
    required this.termMonths,
    required this.status,
    this.createdAt,
    this.disbursedAt,
    this.nextDueDate,
  });

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
    id:           j['id'],
    loanNumber:   j['loan_number'],
    productName:  j['product']?['name'] ?? 'Loan',
    principal:    (j['principal'] as num).toDouble(),
    balance:      (j['balance']   as num).toDouble(),
    paid:         (j['paid']      as num).toDouble(),
    interestRate: (j['interest_rate'] as num).toDouble(),
    termMonths:   j['term_months'] ?? 0,
    status:       j['status'] ?? 'Active',
    createdAt:    j['created_at']    != null ? DateTime.tryParse(j['created_at'].toString())    : null,
    disbursedAt:  j['disbursed_at']  != null ? DateTime.tryParse(j['disbursed_at'].toString())  : null,
    nextDueDate:  j['next_due_date'] != null ? DateTime.tryParse(j['next_due_date'].toString()) : null,
  );

  /// Monthly accrued interest on the remaining balance (same formula as backend).
  double get accruedInterest => (balance * (interestRate / 100) / 12).roundToDouble();

  /// Full amount needed to close the loan right now: principal balance + this month's interest.
  double get settlementAmount => balance + accruedInterest;

  /// Progress based on total settlement (principal + interest paid so far).
  double get repaymentProgress => principal > 0 ? (paid / principal).clamp(0.0, 1.0) : 0.0;

  bool get isOverdue => nextDueDate != null && nextDueDate!.isBefore(DateTime.now()) && status == 'Active';

  bool get isRejected => status == 'Rejected';
  bool get isPending   => status == 'Pending';

  /// Stage index in Submitted → Under Review → Approved → Disbursed, for a
  /// progress stepper. Only meaningful when [isRejected] is false.
  int get progressStage {
    if (isPending) return 1; // Submitted done, Under Review current
    if (disbursedAt == null) return 2; // Approved current, not yet disbursed
    return 3; // Disbursed (or any state past disbursement)
  }
}
