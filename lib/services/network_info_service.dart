import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfoService {
  final Connectivity _connectivity = Connectivity();

  Future<String> getNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _mapResults(results);
    } catch (_) {
      return 'Unknown';
    }
  }

  String _mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data';
    }
    if (results.contains(ConnectivityResult.none)) {
      return 'Offline';
    }
    return 'Unknown';
  }
}
