class ApiConstants {
  static const _prodUrl = 'https://sacco.rinahaintl.com/api/';
  static const baseUrl  = _prodUrl;

  // Auth
  static const login  = '/login';
  static const logout = '/logout';
  static const me     = '/me';

  // Dashboard
  static const dashboard = '/member/dashboard';

  // Savings
  static const savings         = '/member/savings';
  static const savingsProducts = '/member/savings-products';
  static const savingsTxns     = '/member/savings/{id}/transactions';

  // Loans
  static const loans        = '/member/loans';
  static const loanDetail   = '/member/loans/{id}';
  static const loanSchedule = '/member/loans/{id}/schedule';
  static const loanApply    = '/member/loans/apply';
  static const loanProducts = '/member/loan-products';
  static const guarantorRequests       = '/member/guarantor-requests';
  static const guarantorRequestRespond = '/member/guarantor-requests/{id}/respond';
  static const beneficiaries     = '/member/beneficiaries';
  static const beneficiaryItem   = '/member/beneficiaries/{id}';
  static const loanTopUpRequest  = '/member/loans/{id}/top-up-request';
  static const savingsInsights   = '/member/savings-insights';

  // Transactions
  static const transactions = '/member/transactions';

  // Notifications
  static const notifications        = '/member/notifications';
  static const markNotificationsRead= '/member/notifications/mark-all-read';

  // Fixed Deposits
  static const fixedDeposits = '/member/fixed-deposits';

  // Shares
  static const shares                = '/member/shares';
  static const sharePurchaseRequests = '/member/shares/purchase-requests';

  // Bank Details
  static const bankDetails   = '/member/bank-details';
  static const bankDetailDel = '/member/bank-details/{id}';

  // Withdrawal Requests
  static const withdrawalRequests  = '/member/withdrawal-requests';
  static const withdrawalSavings   = '/member/withdrawal-requests/savings';
  static const withdrawalFd        = '/member/withdrawal-requests/fd';

  // Support Tickets
  static const supportTickets      = '/member/support-tickets';
  static const supportTicketDetail = '/member/support-tickets/{id}';
  static const supportTicketReply  = '/member/support-tickets/{id}/reply';

  // KYC
  static const kyc            = '/member/kyc';
  static const kycDocuments   = '/member/kyc/documents';
  static const kycDocumentDel = '/member/kyc/documents/{id}';
  static const kycSelfie      = '/member/kyc/selfie';
  static const kycSelfieChallenge = '/member/kyc/selfie/challenge';

  // Avatar
  static const avatar = '/member/avatar';

  // Account
  static const changePassword = '/member/change-password';
  static const fcmToken       = '/member/fcm-token';

  // PDF Downloads
  static const pdfMemberSummary   = '/pdf/member-summary';
  static const pdfSavings         = '/pdf/savings/{id}';
  static const pdfLoan            = '/pdf/loan/{id}';
  static const pdfFd              = '/pdf/fd/{id}';

  // Savings Goals
  static const goals    = '/member/goals';
  static const goalItem = '/member/goals/{id}';
  static const goalAuto = '/member/goals/{id}/auto';

  // Loan Calculator
  static const loanCalculator = '/member/loan-calculator';

  // Loan Eligibility
  static const loanEligibility = '/member/loan-eligibility';

  // Governance
  static const governance     = '/member/governance';
  static const castVote       = '/member/governance/proposals/{id}/vote';

  // Payments
  static const initiatePayment = '/payments/initiate';
  static const paymentStatus   = '/payments/{reference}';
  static const paymentQuote    = '/payments/quote';

  // Saved mobile-money accounts
  static const momoAccounts    = '/member/momo-accounts';

  // Notification channel preferences (push / sms / email)
  static const notificationPreferences = '/member/notification-preferences';

  // Savings Challenges (gamified saving)
  static const challenges       = '/member/challenges';
  static const challengeItem    = '/member/challenges/{id}';
  static const challengeCellPay = '/member/challenges/{id}/cells/{cell}/pay';

  // App version check (public — no auth required)
  static const appVersion = '/version';

  // Password Reset (public — no auth required)
  static const forgotPassword = '/forgot-password';
  static const resetPassword  = '/reset-password';
  static const registerOptions  = '/register/options';
  static const registerStart    = '/register/start';
  static const registerComplete = '/register/complete';

  // Transaction PIN
  static const transactionPin = '/member/transaction-pin';

  // Sessions & Trusted Devices
  static const sessions             = '/member/sessions';
  static const sessionItem          = '/member/sessions/{id}';
  static const trustedDevices       = '/member/trusted-devices';
  static const trustedDeviceItem    = '/member/trusted-devices/{id}';

  // Dividends & Referrals
  static const dividends = '/member/dividends';
  static const referrals = '/member/referrals';

  // Financial Health & Projections
  static const financialHealth    = '/member/financial-health';
  static const savingsProjection  = '/member/savings/{id}/projection';

  // Transaction Receipts & Mini-Statement
  static const transactionReceipt = '/member/transactions/{id}/receipt';
  static const miniStatement      = '/member/mini-statement';

  // Communication Centre
  static const announcements         = '/member/announcements';
  static const markNotificationRead  = '/member/notifications/{id}/read';

  // Loan Guarantors & Collateral
  static const loanGuarantors      = '/member/loans/{id}/guarantors';
  static const loanCollateral      = '/member/loans/{id}/collateral';
  static const loanSettlementQuote = '/member/loans/{id}/settlement-quote';

  // Member Exit
  static const exitRequests = '/member/exit-requests';

  // Check-Off Statement
  static const checkoff = '/member/checkoff';

  // Credit Score History
  static const creditScoreHistory = '/member/credit-score-history';

  // FD Rollover Toggle
  static const fdRollover = '/member/fixed-deposits/{id}/rollover';

  // Branches
  static const branches = '/branches';

  // Admin: Impersonation
  static const impersonate     = '/admin/impersonate';
  static const impersonateItem = '/admin/impersonate/{id}';

  // Loan Rescheduling
  static const loanRescheduleRequest = '/member/loans/{id}/reschedule-request';

  // Subscription Fee
  static const subscriptionFee    = '/member/subscription-fee';
  static const subscriptionFeePay = '/member/subscription-fee/pay';

  // Constructs a full URL for a storage path like '/storage/avatars/file.jpg'
  static String storageUrl(String path) {
    final base = baseUrl.substring(0, baseUrl.lastIndexOf('api/'));
    return '$base${path.startsWith('/') ? path.substring(1) : path}';
  }

  // Web site root (without the trailing 'api/'), e.g. https://sacco.rinahaintl.com/
  static String get siteRoot => baseUrl.substring(0, baseUrl.lastIndexOf('api/'));

  // Public, admin-editable legal pages (also used as the Play Store privacy URL)
  static String get privacyPolicyUrl => '${siteRoot}privacy-policy';
  static String get termsUrl          => '${siteRoot}terms-and-conditions';

  // Same content, fetched as JSON for native in-app rendering (see legalContent()).
  static const legalContent = '/legal/{type}';
}
