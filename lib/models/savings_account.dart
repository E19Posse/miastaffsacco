class SavingsAccount {
  final int    id;
  final String accountNumber;
  final String productName;
  final double balance;
  final double interestRate;
  final bool   isActive;
  final bool   isLocked;

  const SavingsAccount({
    required this.id,
    required this.accountNumber,
    required this.productName,
    required this.balance,
    required this.interestRate,
    required this.isActive,
    required this.isLocked,
  });

  factory SavingsAccount.fromJson(Map<String, dynamic> j) => SavingsAccount(
    id:            j['id'],
    accountNumber: j['account_number'],
    productName:   j['product']?['name'] ?? j['account_type'] ?? 'Savings',
    balance:       (j['balance'] as num).toDouble(),
    interestRate:  (j['interest_rate'] as num).toDouble(),
    isActive:      j['is_active'] ?? true,
    isLocked:      j['is_locked'] ?? false,
  );
}
