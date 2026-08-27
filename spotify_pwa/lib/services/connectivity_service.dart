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
    _connectivity.onConnectivityChanged.listen((result) {
      if (result is List<ConnectivityResult>) {
        _isOnline = !result.contains(ConnectivityResult.none);
      } else {
        _isOnline = result != ConnectivityResult.none;
      }
      notifyListeners();
    });
  }

  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    if (result is List<ConnectivityResult>) {
      _isOnline = !result.contains(ConnectivityResult.none);
    } else {
      _isOnline = result != ConnectivityResult.none;
    }
    notifyListeners();
    return _isOnline;
  }
}
