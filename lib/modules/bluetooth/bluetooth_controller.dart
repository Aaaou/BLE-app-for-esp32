import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutterblue;
import 'bluetooth_service.dart';

class BluetoothController extends GetxController {
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();

  // 获取蓝牙状态
  bool get isBluetoothOn => _bluetoothService.isBluetoothOn.value;
  bool get isScanning => _bluetoothService.isScanning.value;
  List<flutterblue.ScanResult> get devices => _bluetoothService.devices;

  @override
  void onInit() {
    super.onInit();
    checkBluetoothSupport();
  }

  // 检查蓝牙支持
  Future<void> checkBluetoothSupport() async {
    bool isSupported = await _bluetoothService.checkBleSupport();
    if (!isSupported) {
      Get.snackbar('错误', '此设备不支持BLE蓝牙');
    }
  }

  // 开始扫描
  Future<void> startScan() async {
    await _bluetoothService.startScan();
  }

  // 停止扫描
  void stopScan() {
    _bluetoothService.stopScan();
  }

  // 连接设备
  Future<void> connectToDevice(flutterblue.BluetoothDevice device) async {
    try {
      final bool success = await _bluetoothService.connectToDevice(device);
      if (success) {
        Get.snackbar('成功', '设备连接成功');
      } else {
        Get.snackbar('错误', '设备连接失败');
      }
    } catch (e) {
      Get.snackbar('错误', '连接过程中出现错误');
    }
  }

  // 断开连接
  Future<void> disconnect(flutterblue.BluetoothDevice device) async {
    await _bluetoothService.disconnect(device);
    Get.snackbar('提示', '设备已断开连接');
  }
} 