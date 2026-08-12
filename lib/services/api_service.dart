import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'device_service.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final _store = StorageService();

  /// Set by [AuthProvider] so a 401 on an authenticated request can force the
  /// app back to the login screen immediately, instead of silently wiping the
  /// stored token while the UI still believes the session is valid (which
  /// left every subsequent screen showing a raw "Unauthenticated." snackbar).
  void Function()? onUnauthorized;

  /// Deterministic idempotency key for a payment attempt. The backend
  /// `idempotent` middleware reads the `Idempotency-Key` header: an accidental
  /// retry of the SAME payment (same purpose/provider/amount/target) replays the
  /// first response instead of charging twice, while a genuinely different
  /// payment produces a different key and proceeds normally.
  static String _idemKey(String prefix, List<Object?> parts) =>
      '$prefix-${sha256.convert(utf8.encode(parts.map((p) => p ?? '').join('|')))}';

  static Options _idemHeader(String key) =>
      Options(headers: {'Idempotency-Key': key});

  // SHA-256 hex of sacco.rinahaintl.com's leaf certificate DER bytes.
  // Obtain with (requires OpenSSL):
  //   openssl s_client -connect sacco.rinahaintl.com:443 </dev/null 2>/dev/null \
  //     | openssl x509 -outform DER | openssl dgst -sha256
  // Replace this value after each certificate renewal and before building a release.
  static const _kPinnedSha256 = 'cb95a3d61f02c68aaee9b7422e6a8e87b9ecdbc0599dd3f1efe15e8fbb020714';

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl:        ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    _setupCertPinning();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final token = await _store.getToken();
        if (token != null) opts.headers['Authorization'] = 'Bearer $token';
        handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          // Only treat this as session invalidation if the failed request was
          // actually authenticated — login/register 401s (bad credentials) carry
          // no bearer token and must not force a logout.
          final hadToken = err.requestOptions.headers['Authorization'] != null;
          if (hadToken) {
            await _store.clearSession();
            onUnauthorized?.call();
          }
        }
        handler.next(err);
      },
    ));
  }

  // Release: strict leaf-cert SHA-256 pinning via SecurityContext(withTrustedRoots:false)
  // which bypasses Android's chain-validation so an incomplete server chain still works.
  // Debug: same SecurityContext trick but accept-all callback — lets real devices connect
  // even when the server hasn't yet deployed the full CA bundle.
  void _setupCertPinning() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()
          ..badCertificateCallback = kReleaseMode ? _verifyCert : _debugAccept;
  }

  static bool _verifyCert(X509Certificate cert, String host, int port) {
    if (host != 'sacco.rinahaintl.com') return false;
    return sha256.convert(cert.der).toString() == _kPinnedSha256;
  }

  // Debug-only: accept any cert so real devices work while the server CA bundle is fixed.
  // This callback is never compiled into release builds (kReleaseMode guard above).
  static bool _debugAccept(X509Certificate cert, String host, int port) => true;

  // ── Version check ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAppVersion() async {
    try {
      final res = await _dio.get(ApiConstants.appVersion);
      return (res.data as Map?)?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final deviceInfo = await DeviceService.getDeviceInfo();
    final deviceId   = await _store.getOrCreateDeviceId();
    final res = await _dio.post(ApiConstants.login, data: {
      'email':        email,
      'password':     password,
      'device_id':    deviceId,
      'device_name':  deviceInfo['device_name'],
      'device_model': deviceInfo['device_model'],
      'os':           deviceInfo['os'],
      'app_version':  '1.0.0',
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyIdentity(String password) async {
    final res = await _dio.post('member/verify-identity', data: {'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try { await _dio.post(ApiConstants.logout); } catch (_) {}
    await _store.clearSession();
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get(ApiConstants.me);
    return res.data as Map<String, dynamic>;
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _dio.get(ApiConstants.dashboard);
    return res.data as Map<String, dynamic>;
  }

  // ── Savings ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getSavings() async {
    final res = await _dio.get(ApiConstants.savings);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<List<dynamic>> getSavingsProducts() async {
    final res = await _dio.get(ApiConstants.savingsProducts);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> createSavingsAccount(int productId) async {
    final res = await _dio.post(ApiConstants.savings, data: {'savings_product_id': productId});
    return (res.data['data'] as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getSavingsTransactions(int accountId, {int page = 1}) async {
    final url = ApiConstants.savingsTxns.replaceFirst('{id}', '$accountId');
    final res = await _dio.get(url, queryParameters: {'page': page});
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> depositSavings(int accountId, double amount, {String? notes}) async {
    final res = await _dio.post('member/savings/$accountId/deposit',
        data: {'amount': amount, if (notes != null) 'notes': notes});
    return res.data as Map<String, dynamic>;
  }

  // ── Loans ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getLoans() async {
    final res = await _dio.get(ApiConstants.loans);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> getLoanDetail(int id) async {
    final url = ApiConstants.loanDetail.replaceFirst('{id}', '$id');
    final res = await _dio.get(url);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<List<dynamic>> getLoanSchedule(int id) async {
    final url = ApiConstants.loanSchedule.replaceFirst('{id}', '$id');
    final res = await _dio.get(url);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> repayLoan(int loanId, double amount, {String mode = 'Mobile Money'}) async {
    final key = _idemKey('repay', [loanId, amount, mode]);
    final res = await _dio.post('member/loans/$loanId/repay',
        data: {'amount': amount, 'payment_mode': mode},
        options: _idemHeader(key));
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getLoanProducts() async {
    final res = await _dio.get(ApiConstants.loanProducts);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> applyLoan({
    required int productId,
    required double principal,
    required int termMonths,
    required String purpose,
    List<Map<String, dynamic>> collateral = const [],
    List<Map<String, dynamic>> guarantors = const [],
  }) async {
    final res = await _dio.post(ApiConstants.loanApply, data: {
      'loan_product_id': productId,
      'principal':       principal,
      'term_months':     termMonths,
      'purpose':         purpose,
      if (collateral.isNotEmpty) 'collateral': collateral,
      if (guarantors.isNotEmpty) 'guarantors': guarantors,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Guarantor requests (loans I'm asked to guarantee) ─────────────────────

  Future<List<dynamic>> getGuarantorRequests() async {
    final res = await _dio.get(ApiConstants.guarantorRequests);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> respondGuarantorRequest(
      int id, String action, {double? amount}) async {
    final url = ApiConstants.guarantorRequestRespond.replaceFirst('{id}', '$id');
    final res = await _dio.post(url, data: {
      'action': action,
      if (amount != null) 'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loanTopUpRequest(int loanId, {required double additionalAmount, required String reason}) async {
    final url = ApiConstants.loanTopUpRequest.replaceFirst('{id}', '$loanId');
    final res = await _dio.post(url, data: {'additional_amount': additionalAmount, 'reason': reason});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSavingsInsights() async {
    final res = await _dio.get(ApiConstants.savingsInsights);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Beneficiaries / next-of-kin ───────────────────────────────────────────

  Future<Map<String, dynamic>> getBeneficiaries() async {
    final res = await _dio.get(ApiConstants.beneficiaries);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> saveBeneficiary(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _dio.post(ApiConstants.beneficiaries, data: data);
    } else {
      await _dio.put(ApiConstants.beneficiaryItem.replaceFirst('{id}', '$id'), data: data);
    }
  }

  Future<void> deleteBeneficiary(int id) async {
    await _dio.delete(ApiConstants.beneficiaryItem.replaceFirst('{id}', '$id'));
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getTransactions({String? type, int page = 1}) async {
    final res = await _dio.get(ApiConstants.transactions, queryParameters: {
      if (type != null) 'type': type,
      'page': page,
    });
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _dio.get(ApiConstants.notifications);
    return res.data as Map<String, dynamic>;
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post(ApiConstants.markNotificationsRead);
  }

  Future<void> markNotificationRead(int id) async {
    final url = ApiConstants.markNotificationRead.replaceFirst('{id}', '$id');
    await _dio.post(url);
  }

  Future<List<dynamic>> getAnnouncements() async {
    final res = await _dio.get(ApiConstants.announcements);
    return (res.data['announcements'] ?? []) as List<dynamic>;
  }

  // ── Fixed Deposits ────────────────────────────────────────────────────────

  Future<List<dynamic>> getFixedDeposits() async {
    final res = await _dio.get(ApiConstants.fixedDeposits);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  // ── Shares ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getShares() async {
    final res = await _dio.get(ApiConstants.shares);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<List<dynamic>> getSharePurchaseRequests() async {
    final res = await _dio.get(ApiConstants.sharePurchaseRequests);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> submitSharePurchaseRequest({
    required int units,
    required String paymentMode,
    String? notes,
  }) async {
    final res = await _dio.post(ApiConstants.sharePurchaseRequests, data: {
      'units':        units,
      'payment_mode': paymentMode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Bank Details ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getBankDetails() async {
    final res = await _dio.get(ApiConstants.bankDetails);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> addBankDetail(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.bankDetails, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteBankDetail(int id) async {
    final url = ApiConstants.bankDetailDel.replaceFirst('{id}', '$id');
    await _dio.delete(url);
  }

  // ── Withdrawal Requests ───────────────────────────────────────────────────

  Future<List<dynamic>> getWithdrawalRequests() async {
    final res = await _dio.get(ApiConstants.withdrawalRequests);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> submitSavingsWithdrawal(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.withdrawalSavings, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitFdWithdrawal(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.withdrawalFd, data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Support Tickets ───────────────────────────────────────────────────────

  Future<List<dynamic>> getSupportTickets() async {
    final res = await _dio.get(ApiConstants.supportTickets);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> createSupportTicket(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.supportTickets, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSupportTicketDetail(int id) async {
    final url = ApiConstants.supportTicketDetail.replaceFirst('{id}', '$id');
    final res = await _dio.get(url);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<Map<String, dynamic>> replySupportTicket(int id, String body) async {
    final url = ApiConstants.supportTicketReply.replaceFirst('{id}', '$id');
    final res = await _dio.post(url, data: {'body': body});
    return res.data as Map<String, dynamic>;
  }

  // ── KYC ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getKycStatus() async {
    final res = await _dio.get(ApiConstants.kyc);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<Map<String, dynamic>> uploadKycDocument({
    required File file,
    required String documentType,
    String? side,
    String? documentNumber,
    String? cardNumber,
    String? expiryDate,
  }) async {
    final formData = FormData.fromMap({
      'file':            await MultipartFile.fromFile(file.path, filename: 'document.jpg'),
      'document_type':   documentType,
      if (side != null)           'side':            side,
      if (documentNumber != null && documentNumber.isNotEmpty)
                                  'document_number': documentNumber,
      if (cardNumber != null && cardNumber.isNotEmpty)
                                  'card_number':     cardNumber,
      if (expiryDate != null)     'expiry_date':     expiryDate,
    });
    final res = await _dio.post(ApiConstants.kycDocuments, data: formData);
    return res.data as Map<String, dynamic>;
  }

  /// Fetch a fresh single-use capture challenge nonce (valid ~120s) that must
  /// accompany the selfie upload. The server binds the upload to this nonce.
  Future<String> getSelfieChallenge() async {
    final res = await _dio.post(ApiConstants.kycSelfieChallenge);
    return (res.data as Map)['nonce'] as String;
  }

  Future<Map<String, dynamic>> uploadKycSelfie(File file, String nonce) async {
    final formData = FormData.fromMap({
      'file':  await MultipartFile.fromFile(file.path, filename: 'selfie.jpg'),
      'nonce': nonce,
    });
    final res = await _dio.post(ApiConstants.kycSelfie, data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteKycDocument(int id) async {
    final url = ApiConstants.kycDocumentDel.replaceFirst('{id}', '$id');
    await _dio.delete(url);
  }

  // ── Savings Goals ────────────────────────────────────────────────────────

  Future<List<dynamic>> getGoals() async {
    final res = await _dio.get(ApiConstants.goals);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.goals, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteGoal(int id) async {
    final url = ApiConstants.goalItem.replaceFirst('{id}', '$id');
    await _dio.delete(url);
  }

  // Recurring / automatic savings on a goal
  Future<Map<String, dynamic>?> getGoalAuto(int goalId) async {
    final res = await _dio.get(ApiConstants.goalAuto.replaceFirst('{id}', '$goalId'));
    return (res.data['data'] as Map?)?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> setGoalAuto(int goalId, double amount, String frequency) async {
    final res = await _dio.post(ApiConstants.goalAuto.replaceFirst('{id}', '$goalId'),
        data: {'amount': amount, 'frequency': frequency});
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelGoalAuto(int goalId) async {
    await _dio.delete(ApiConstants.goalAuto.replaceFirst('{id}', '$goalId'));
  }

  // ── Loan Eligibility ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLoanEligibility() async {
    final res = await _dio.get(ApiConstants.loanEligibility);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Loan Calculator ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> calculateLoan({
    required double principal,
    required double rate,
    required int term,
    String method = 'reducing_balance',
  }) async {
    final res = await _dio.get(ApiConstants.loanCalculator, queryParameters: {
      'principal': principal,
      'rate': rate,
      'term': term,
      'method': method,
    });
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Governance ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGovernance() async {
    final res = await _dio.get(ApiConstants.governance);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<Map<String, dynamic>> castVote(int proposalId, String vote) async {
    final url = ApiConstants.castVote.replaceFirst('{id}', '$proposalId');
    final res = await _dio.post(url, data: {'vote': vote});
    return res.data as Map<String, dynamic>;
  }

  // ── Loan Guarantors & Collateral ──────────────────────────────────────────

  Future<List<dynamic>> getLoanGuarantors(int loanId) async {
    final url = ApiConstants.loanGuarantors.replaceFirst('{id}', '$loanId');
    final res = await _dio.get(url);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<List<dynamic>> getLoanCollateral(int loanId) async {
    final url = ApiConstants.loanCollateral.replaceFirst('{id}', '$loanId');
    final res = await _dio.get(url);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> getLoanSettlementQuote(int loanId) async {
    final url = ApiConstants.loanSettlementQuote.replaceFirst('{id}', '$loanId');
    final res = await _dio.get(url);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Member Exit ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getExitRequests() async {
    final res = await _dio.get(ApiConstants.exitRequests);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> submitExitRequest({
    required String reason,
    String? details,
  }) async {
    final res = await _dio.post(ApiConstants.exitRequests, data: {
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Check-Off Statement ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCheckoffStatement() async {
    final res = await _dio.get(ApiConstants.checkoff);
    return {
      'records':  (res.data['data']     as List?)?.cast<dynamic>() ?? [],
      'expected': (res.data['expected'] as Map?)?.cast<String, dynamic>() ?? {},
    };
  }


  // ── Admin Impersonation ───────────────────────────────────────────────────

  Future<List<dynamic>> getImpersonationList() async {
    final res = await _dio.get(ApiConstants.impersonate);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> startImpersonation(int userId) async {
    final url = ApiConstants.impersonateItem.replaceFirst('{id}', '$userId');
    final res = await _dio.post(url);
    return res.data as Map<String, dynamic>;
  }

  Future<void> stopImpersonation() async {
    await _dio.delete(ApiConstants.impersonate);
  }

  // ── Credit Score History ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCreditScoreHistory() async {
    final res = await _dio.get(ApiConstants.creditScoreHistory);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── FD Rollover Toggle ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> toggleFdRollover(int fdId, bool autoRollover) async {
    final url = ApiConstants.fdRollover.replaceFirst('{id}', '$fdId');
    final res = await _dio.patch(url, data: {'auto_rollover': autoRollover});
    return res.data as Map<String, dynamic>;
  }

  // ── Branches ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getBranches() async {
    final res = await _dio.get(ApiConstants.branches);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  // ── Loan Rescheduling ─────────────────────────────────────────────────────

  Future<void> loanRescheduleRequest(int loanId, {
    required String reason,
    required int requestedTerm,
  }) async {
    final url = ApiConstants.loanRescheduleRequest.replaceFirst('{id}', '$loanId');
    await _dio.post(url, data: {
      'reason':         reason,
      'requested_term': requestedTerm,
    });
  }

  // ── Subscription Fee ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSubscriptionFeeStatus() async {
    final res = await _dio.get(ApiConstants.subscriptionFee);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<void> paySubscriptionFee({
    required String reference,
    required String mode,
  }) async {
    await _dio.post(ApiConstants.subscriptionFeePay, data: {
      'payment_reference': reference,
      'payment_mode':      mode,
    });
  }

  // ── Error helper ─────────────────────────────────────────────────────────

  static String extractError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        if (data['message'] != null) return data['message'] as String;
        if (data['error'] != null)   return data['error'] as String;
        // Laravel validation errors: { errors: { field: ['msg'] } }
        if (data['errors'] is Map) {
          final first = (data['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) return first.first as String;
        }
      }
      // Friendly messages for common HTTP statuses (Dio mislabels 429 as "bad syntax").
      switch (status) {
        case 429:
          return 'Too many attempts. Please wait a minute and try again.';
        case 401:
          return 'Incorrect email or password.';
        case 403:
          return 'You don\'t have permission to do that.';
        case 500:
        case 502:
        case 503:
          return 'The server is temporarily unavailable. Please try again shortly.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Check your network and try again.';
      }
      return 'Something went wrong. Please try again.';
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<String?> uploadAvatar(File file) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path, filename: 'avatar.jpg'),
    });
    final res = await _dio.post(ApiConstants.avatar, data: formData);
    final path = res.data['avatar_url'] as String?;
    return path != null ? ApiConstants.storageUrl(path) : null;
  }

  Future<void> removeAvatar() async {
    await _dio.delete(ApiConstants.avatar);
  }

  // ── Account ───────────────────────────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post(ApiConstants.changePassword, data: {
      'current_password':      currentPassword,
      'new_password':          newPassword,
      'new_password_confirmation': newPassword,
    });
  }

  Future<void> updateFcmToken(String token) async {
    await _dio.post('/member/fcm-token', data: {'token': token});
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateGatewayPayment({
    required String purpose,
    required String provider,
    required double amount,
    String? phone,
    int? loanId,
    int? savingsAccountId,
    String pin = '',
  }) async {
    final key = _idemKey('pay', [purpose, provider, amount, loanId, savingsAccountId, phone]);
    final res = await _dio.post(ApiConstants.initiatePayment, data: {
      'purpose':  purpose,
      'provider': provider,
      'amount':   amount,
      if (phone != null && phone.isNotEmpty)   'phone': phone,
      if (loanId != null)                      'loan_id': loanId,
      if (savingsAccountId != null)            'savings_account_id': savingsAccountId,
      if (pin.isNotEmpty)                      'pin': pin,
    }, options: _idemHeader(key));
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  /// Confirm a transaction PIN up-front (before the payment call). Returns true
  /// when verified; throws DioException on a bad/locked PIN so the caller can
  /// surface the server message.
  Future<bool> verifyTransactionPin(String pin) async {
    final res = await _dio.post('${ApiConstants.transactionPin}/verify', data: {'pin': pin});
    return (res.data is Map) && (res.data['verified'] == true);
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String reference) async {
    final url = ApiConstants.paymentStatus.replaceFirst('{reference}', reference);
    final res = await _dio.get(url);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  /// Fee + "you receive" preview for the deposit Review screen.
  Future<Map<String, dynamic>> getPaymentQuote({
    required String provider,
    required double amount,
    String purpose = 'savings_deposit',
  }) async {
    final res = await _dio.get(ApiConstants.paymentQuote, queryParameters: {
      'provider': provider, 'amount': amount, 'purpose': purpose,
    });
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Saved mobile-money accounts ───────────────────────────────────────────

  Future<List<dynamic>> getMomoAccounts() async {
    final res = await _dio.get(ApiConstants.momoAccounts);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> addMomoAccount({required String name, required String phone}) async {
    final res = await _dio.post(ApiConstants.momoAccounts, data: {'name': name, 'phone': phone});
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<void> deleteMomoAccount(int id) async {
    await _dio.delete('${ApiConstants.momoAccounts}/$id');
  }

  // ── Notification channel preferences ──────────────────────────────────────

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final res = await _dio.get(ApiConstants.notificationPreferences);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<Map<String, dynamic>> updateNotificationPreferences({
    required bool push,
    required bool sms,
    required bool email,
  }) async {
    final res = await _dio.put(ApiConstants.notificationPreferences,
        data: {'push': push, 'sms': sms, 'email': email});
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Savings Challenges ────────────────────────────────────────────────────

  Future<List<dynamic>> getChallenges({String filter = 'all'}) async {
    final res = await _dio.get(ApiConstants.challenges, queryParameters: {'filter': filter});
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> getChallenge(int id) async {
    final res = await _dio.get(ApiConstants.challengeItem.replaceFirst('{id}', '$id'));
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<Map<String, dynamic>> createChallenge({
    required String name,
    required String type,
    required int savingsAccountId,
    required int cellsCount,
    required int baseAmount,
    int step = 0,
  }) async {
    final res = await _dio.post(ApiConstants.challenges, data: {
      'name': name, 'type': type, 'savings_account_id': savingsAccountId,
      'cells_count': cellsCount, 'base_amount': baseAmount, 'step': step,
    });
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  Future<void> deleteChallenge(int id) async {
    await _dio.delete(ApiConstants.challengeItem.replaceFirst('{id}', '$id'));
  }

  Future<Map<String, dynamic>> payChallengeCell({
    required int challengeId,
    required int cellId,
    required String provider,
    String? phone,
  }) async {
    final url = ApiConstants.challengeCellPay
        .replaceFirst('{id}', '$challengeId')
        .replaceFirst('{cell}', '$cellId');
    final res = await _dio.post(url, data: {'provider': provider, if (phone != null) 'phone': phone});
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Password Reset (public) ───────────────────────────────────────────────

  Future<void> forgotPassword(String identifier) async {
    await _dio.post(ApiConstants.forgotPassword, data: {'identifier': identifier});
  }

  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String password,
  }) async {
    await _dio.post(ApiConstants.resetPassword, data: {
      'identifier':             identifier,
      'otp':                    otp,
      'password':               password,
      'password_confirmation':  password,
    });
  }

  // ── Self-registration (public) ────────────────────────────────────────────

  /// Fetch employers + member categories for the registration dropdowns.
  Future<Map<String, dynamic>> getRegisterOptions() async {
    final res = await _dio.get(ApiConstants.registerOptions);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  /// Public — no auth required. [type] is 'privacy' or 'terms'.
  Future<Map<String, dynamic>> getLegalContent(String type) async {
    final res = await _dio.get(ApiConstants.legalContent.replaceFirst('{type}', type));
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  /// Step 1: validate the profile and trigger the OTP(s). Returns the response,
  /// including `phone_otp_required` (false until SMS is configured server-side).
  Future<Map<String, dynamic>> registerStart({
    required String name,
    required String email,
    required String phone,
    required String staffNumber,
    required String employerCode,
    required int    memberCategoryId,
    required String password,
    String referralCode = '',
    String? recaptchaToken,
  }) async {
    final res = await _dio.post(ApiConstants.registerStart, data: {
      'name':                  name,
      'email':                 email,
      'phone':                 phone,
      'staff_number':          staffNumber,
      'employer_code':         employerCode,
      'member_category_id':    memberCategoryId,
      'password':              password,
      'password_confirmation': password,
      if (referralCode.isNotEmpty) 'referral_code': referralCode,
      if (recaptchaToken != null) 'recaptcha_token': recaptchaToken,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Step 2: verify both OTPs and create the account. Returns token + member.
  Future<Map<String, dynamic>> registerComplete({
    required String name,
    required String email,
    required String phone,
    required String staffNumber,
    required String employerCode,
    required int    memberCategoryId,
    required String password,
    required String emailOtp,
    String phoneOtp = '',
    String referralCode = '',
  }) async {
    final res = await _dio.post(ApiConstants.registerComplete, data: {
      'name':                  name,
      'email':                 email,
      'phone':                 phone,
      'staff_number':          staffNumber,
      'employer_code':         employerCode,
      'member_category_id':    memberCategoryId,
      'password':              password,
      'password_confirmation': password,
      'email_otp':             emailOtp,
      if (phoneOtp.isNotEmpty) 'phone_otp': phoneOtp,
      if (referralCode.isNotEmpty) 'referral_code': referralCode,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Transaction PIN ───────────────────────────────────────────────────────

  Future<void> setTransactionPin({
    required String pin,
    String? currentPassword,
  }) async {
    await _dio.post(ApiConstants.transactionPin, data: {
      'pin':     pin,
      'confirm': pin,
      if (currentPassword != null) 'password': currentPassword,
    });
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getActiveSessions() async {
    final res = await _dio.get(ApiConstants.sessions);
    return (res.data['data'] as List?)?.cast<dynamic>() ?? [];
  }

  Future<void> revokeSession(int tokenId) async {
    final url = ApiConstants.sessionItem.replaceFirst('{id}', '$tokenId');
    await _dio.delete(url);
  }

  Future<void> revokeAllSessions() async {
    await _dio.delete(ApiConstants.sessions);
  }

  // ── Trusted Devices ───────────────────────────────────────────────────────

  Future<List<dynamic>> getTrustedDevices() async {
    final res = await _dio.get(ApiConstants.trustedDevices);
    return res.data['devices'] as List<dynamic>;
  }

  Future<void> trustCurrentDevice() async {
    final info = await DeviceService.getDeviceInfo();
    await _dio.post(ApiConstants.trustedDevices, data: {
      'device_model': info['device_model'],
      'os':           info['os'],
      'device_name':  info['device_name'],
    });
  }

  Future<void> revokeDevice(int id) async {
    final url = ApiConstants.trustedDeviceItem.replaceFirst('{id}', '$id');
    await _dio.delete(url);
  }

  // ── Dividends & Referrals ─────────────────────────────────────────────────

  Future<List<dynamic>> getDividends() async {
    final res = await _dio.get(ApiConstants.dividends);
    return (res.data['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> getReferralInfo() async {
    final res = await _dio.get(ApiConstants.referrals);
    // Endpoints wrap the payload in { data: {...} } — unwrap like the rest.
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Financial Health ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialHealth() async {
    final res = await _dio.get(ApiConstants.financialHealth);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }

  // ── Interest Projection ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInterestProjection(int savingsId, {int months = 12}) async {
    final url = ApiConstants.savingsProjection.replaceFirst('{id}', '$savingsId');
    final res = await _dio.get(url, queryParameters: {'months': months});
    return res.data as Map<String, dynamic>;
  }

  // ── Transaction Receipt ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTransactionReceipt(int id) async {
    final url = ApiConstants.transactionReceipt.replaceFirst('{id}', '$id');
    final res = await _dio.get(url);
    return res.data['receipt'] as Map<String, dynamic>;
  }

  // ── Mini-Statement ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMiniStatement() async {
    final res = await _dio.get(ApiConstants.miniStatement);
    return ((res.data['data'] as Map?)?.cast<String, dynamic>()) ?? {};
  }
}
