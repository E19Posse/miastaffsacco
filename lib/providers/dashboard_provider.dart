import 'package:flutter/foundation.dart';
import '../models/loan.dart';
import '../models/notification.dart';
import '../models/savings_account.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final _api = ApiService();

  bool   _loading    = false;
  String? _error;

  double _totalSavings = 0;
  double _totalLoans   = 0;
  int    _activeLoans  = 0;
  int    _overdueLoans = 0;

  List<SavingsAccount>    _savings       = [];
  List<Loan>              _loans         = [];
  List<AppTransaction>    _transactions  = [];
  List<AppNotification>   _notifications = [];
  int                     _unreadCount   = 0;

  bool   get loading        => _loading;
  String? get error         => _error;
  double get totalSavings   => _totalSavings;
  double get totalLoans     => _totalLoans;
  int    get activeLoans    => _activeLoans;
  int    get overdueLoans   => _overdueLoans;
  List<SavingsAccount>  get savings       => _savings;
  List<Loan>            get loans         => _loans;
  List<AppTransaction>  get transactions  => _transactions;
  List<AppNotification> get notifications => _notifications;
  int                   get unreadCount   => _unreadCount;

  Future<void> loadAll() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getSavings(),
        _api.getLoans(),
        _api.getTransactions(),
        _api.getNotifications(),
      ]);

      _savings       = (results[0] as List<dynamic>).map((j) => SavingsAccount.fromJson(j)).toList();
      _loans         = (results[1] as List<dynamic>).map((j) => Loan.fromJson(j)).toList();
      _transactions  = (results[2] as List<dynamic>).map((j) => AppTransaction.fromJson(j)).toList();

      final notifData = results[3] as Map<String, dynamic>;
      _notifications = (notifData['data'] as List<dynamic>)
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      _unreadCount = notifData['unread_count'] as int? ?? 0;

      _totalSavings = _savings.fold(0, (s, a) => s + a.balance);
      _totalLoans   = _loans.where((l) => l.status == 'Active').fold(0, (s, l) => s + l.balance);
      _activeLoans  = _loans.where((l) => l.status == 'Active').length;
      _overdueLoans = _loans.where((l) => l.isOverdue).length;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id, type: n.type, title: n.title,
                message: n.message, isRead: true,
                link: n.link, createdAt: n.createdAt,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refresh() => loadAll();

  /// Mirrors a mark-all-read that already happened via [NotificationsScreen]
  /// calling the API directly, so the shared bell-badge count updates without
  /// waiting for the next full [loadAll] (e.g. on next login).
  void clearUnreadLocally() {
    _notifications = _notifications
        .map((n) => AppNotification(
              id: n.id, type: n.type, title: n.title,
              message: n.message, isRead: true,
              link: n.link, createdAt: n.createdAt,
            ))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  /// Mirrors a single mark-read that already happened via the API, decrementing
  /// the shared bell-badge count if that notification was still unread.
  void markOneReadLocally(int id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    final n = _notifications[idx];
    _notifications[idx] = AppNotification(
      id: n.id, type: n.type, title: n.title,
      message: n.message, isRead: true,
      link: n.link, createdAt: n.createdAt,
    );
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
  }
}
