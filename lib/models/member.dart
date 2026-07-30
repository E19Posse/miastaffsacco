import '../constants/api_constants.dart';

class Member {
  final int    id;
  final String name;
  final String memberNumber;
  final String email;
  final String phone;
  final String kycStatus;
  final bool   kycLocked;
  final String approvalStatus;
  final String? avatarUrl;
  final DateTime joinedAt;
  final bool subscriptionFeePaid;
  final int     creditScore;
  final String? creditTierRaw;
  final String? roleId;
  final bool    requireTxnPin;
  final bool    hasTxnPin;

  const Member({
    required this.id,
    required this.name,
    required this.memberNumber,
    required this.email,
    required this.phone,
    required this.kycStatus,
    this.kycLocked = false,
    this.approvalStatus = 'approved',
    this.avatarUrl,
    required this.joinedAt,
    this.subscriptionFeePaid = false,
    this.creditScore = 0,
    this.creditTierRaw,
    this.roleId,
    this.requireTxnPin = false,
    this.hasTxnPin = false,
  });

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id:                  j['id'],
    name:                j['name'],
    memberNumber:        j['member_number'],
    email:               j['email']  ?? '',
    phone:               j['phone']  ?? '',
    kycStatus:           j['kyc_status'] ?? 'Pending',
    kycLocked:           j['kyc_locked'] == true,
    approvalStatus:      j['approval_status'] ?? 'approved',
    avatarUrl:           j['avatar_url'] != null
        ? ApiConstants.storageUrl(j['avatar_url'] as String)
        : null,
    joinedAt:            DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    subscriptionFeePaid: j['subscription_fee_paid'] == true,
    creditScore:         int.tryParse('${j['credit_score'] ?? 0}') ?? 0,
    creditTierRaw:       j['credit_tier'] as String?,
    roleId:              j['role_id'] as String?,
    requireTxnPin:       j['require_txn_pin'] == true,
    hasTxnPin:           j['has_txn_pin'] == true,
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }

  bool get isKycVerified  => kycStatus == 'Verified';

  /// Self-registered members start 'pending' until staff approve them.
  bool get isApproved        => approvalStatus == 'approved';
  bool get isApprovalPending => approvalStatus == 'pending';

  /// Verification-badge tier: 'gold' (≥750), 'bronze' (400–749), or 'basic'
  /// (<400). Prefers the server-computed value (single source of truth, see
  /// CreditScoreService::badgeTier()); falls back to deriving it locally only
  /// if an older server response doesn't include credit_tier yet.
  String get creditTier => creditTierRaw ?? (
    creditScore >= 750 ? 'gold' : (creditScore >= 400 ? 'bronze' : 'basic')
  );

  bool get isGoldVerified => creditTier == 'gold';

  /// True only for ROLE_SYSADMIN — can impersonate other users.
  bool get isAdmin => roleId == 'ROLE_SYSADMIN';

  Member withAvatar(String? url) => Member(
    id: id, name: name, memberNumber: memberNumber,
    email: email, phone: phone, kycStatus: kycStatus,
    kycLocked: kycLocked,
    approvalStatus: approvalStatus,
    avatarUrl: url, joinedAt: joinedAt,
    subscriptionFeePaid: subscriptionFeePaid,
    creditScore: creditScore, creditTierRaw: creditTierRaw, roleId: roleId,
    requireTxnPin: requireTxnPin, hasTxnPin: hasTxnPin,
  );
}
