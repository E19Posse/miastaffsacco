enum TxnType { savings, loan, payment, transfer, refund, other }

class AppTransaction {
  final int       id;
  final String    reference;
  final String    description;
  final double    amount;
  final bool      isCredit;
  final TxnType   type;
  final String    status;
  final DateTime  date;
  final String    channel; // manual | mobile_money | online

  const AppTransaction({
    required this.id,
    required this.reference,
    required this.description,
    required this.amount,
    required this.isCredit,
    required this.type,
    required this.status,
    required this.date,
    this.channel = 'manual',
  });

  bool get isMobileMoney => channel == 'mobile_money';

  factory AppTransaction.fromJson(Map<String, dynamic> j) {
    final rawType = (j['type'] as String? ?? '').toLowerCase();
    TxnType t;
    switch (rawType) {
      case 'savings':      t = TxnType.savings;  break;
      case 'loan':         t = TxnType.loan;     break;
      case 'payment':      t = TxnType.payment;  break;
      case 'refund':       t = TxnType.refund;   break;
      case 'transfer in':
      case 'transfer out':
      case 'transfer':     t = TxnType.transfer; break;
      default:             t = TxnType.other;
    }

    // For transfers, derive isCredit from the type name if backend
    // doesn't send is_credit explicitly.
    bool isCredit = j['is_credit'] as bool? ?? false;
    if (rawType == 'transfer in')  isCredit = true;
    if (rawType == 'transfer out') isCredit = false;

    return AppTransaction(
      id:          j['id'] as int,
      reference:   j['reference']   as String? ?? '',
      description: j['description'] as String? ?? '',
      amount:      (j['amount'] as num).abs().toDouble(),
      isCredit:    isCredit,
      type:        t,
      status:      j['status']      as String? ?? 'Completed',
      date:        DateTime.tryParse(j['date'] as String? ?? j['created_at'] as String? ?? '') ?? DateTime.now(),
      channel:     j['channel']     as String? ?? 'manual',
    );
  }
}
