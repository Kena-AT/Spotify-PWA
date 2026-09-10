import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityService() {
    _init();
  }

  void _init() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }

  Future<bool> checkConnection() async {
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    notifyListeners();
    return _isOnline;
  }
}
