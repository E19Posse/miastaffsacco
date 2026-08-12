import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetStatus { online, offline, checking }

/// App-wide network reachability. `connectivity_plus` alone only reports link
/// type (wifi/mobile/none) — it says "connected" even behind a captive portal
/// with no real internet — so every link-up event is confirmed with a real
/// DNS lookup before we tell the UI we're online.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _controller = StreamController<NetStatus>.broadcast();
  Stream<NetStatus> get statusStream => _controller.stream;

  NetStatus _last = NetStatus.online;
  NetStatus get last => _last;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _sub = Connectivity().onConnectivityChanged.listen(_onChange);
    _probe();
  }

  void dispose() {
    _sub?.cancel();
    _started = false;
  }

  Future<void> _onChange(List<ConnectivityResult> results) async {
    if (results.every((r) => r == ConnectivityResult.none)) {
      _emit(NetStatus.offline);
      return;
    }
    _emit(NetStatus.checking);
    await _probe();
  }

  Future<void> _probe() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 4));
      _emit(result.isNotEmpty && result.first.rawAddress.isNotEmpty
          ? NetStatus.online
          : NetStatus.offline);
    } catch (_) {
      _emit(NetStatus.offline);
    }
  }

  void _emit(NetStatus s) {
    _last = s;
    _controller.add(s);
  }
}
