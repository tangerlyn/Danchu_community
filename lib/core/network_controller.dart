import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class NetworkController extends GetxController {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;
  Timer? _debounceTimer;

  // 초기값을 true로 설정 (연결됐다고 가정하고 시작)
  var isConnected = true.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    // 1. 즉시 현재 상태 확인
    final result = await _connectivity.checkConnectivity();
    final connected = result.any((r) => r != ConnectivityResult.none);
    isConnected.value = connected;

    // 2. 이후 변경사항 구독
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final connected = result.any((r) => r != ConnectivityResult.none);

    if (connected) {
      // 연결 복구 → 즉시 배너 숨김
      _debounceTimer?.cancel();
      isConnected.value = true;
    } else {
      // 연결 끊김 → 3초 후 배너 표시
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 3), () {
        isConnected.value = false;
      });
    }
  }

  /// 외부에서 강제로 연결 상태 재확인 (화면 전환 시 호출)
  Future<void> recheck() async {
    final result = await _connectivity.checkConnectivity();
    final connected = result.any((r) => r != ConnectivityResult.none);
    isConnected.value = connected;
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.onClose();
  }
}
