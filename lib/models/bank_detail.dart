class BankDetail {
  final int     id;
  final String  bankName;
  final String? branchName;
  final String  accountName;
  final String  accountNumber;
  final String? swiftCode;
  final bool    isPrimary;

  const BankDetail({
    required this.id,
    required this.bankName,
    this.branchName,
    required this.accountName,
    required this.accountNumber,
    this.swiftCode,
    required this.isPrimary,
  });

  factory BankDetail.fromJson(Map<String, dynamic> j) => BankDetail(
    id:            j['id'] as int,
    bankName:      j['bank_name'] as String,
    branchName:    j['branch_name'] as String?,
    accountName:   j['account_name'] as String,
    accountNumber: j['account_number'] as String,
    swiftCode:     j['swift_code'] as String?,
    isPrimary:     j['is_primary'] as bool? ?? false,
  );
}
