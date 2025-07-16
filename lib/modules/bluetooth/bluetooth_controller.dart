import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutterblue;
import 'bluetooth_service.dart';
import 'dart:developer' as developer;

class BluetoothController extends GetxController {
  final BluetoothService _bluetoothService = Get.find<BluetoothService>();

  // 获取蓝牙状态
  bool get isBluetoothOn => _bluetoothService.isBluetoothOn.value;
  bool get isScanning => _bluetoothService.isScanning.value;
  List<flutterblue.ScanResult> get devices => _bluetoothService.devices;
  List<flutterblue.BluetoothDevice> get bondedDevices => _bluetoothService.bondedDevices;

  // 获取设备连接状态
  bool isDeviceConnected(String deviceId) => _bluetoothService.isDeviceConnected(deviceId);
  
  // 获取设备配对状态
  bool isDevicePaired(String deviceId) => _bluetoothService.isDevicePaired(deviceId);

  // 新增：隐藏未知设备的开关
  final RxBool hideUnknownDevices = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkBluetoothSupport();
    // 进入页面时主动扫描一次
    startScan();
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
    try {
      developer.log('Starting scan process', name: 'BluetoothController');
      
      // 先请求必要的权限
      bool hasPermission = await _bluetoothService.requestPermissions();
      developer.log('Permission check result: $hasPermission', name: 'BluetoothController');
      
      if (!hasPermission) {
        Get.snackbar('错误', '需要蓝牙和定位权限才能扫描设备');
        return;
      }
      
      await _bluetoothService.startScan();
      developer.log('Scan started successfully', name: 'BluetoothController');
    } catch (e) {
      developer.log('Scan error: ${e.toString()}', name: 'BluetoothController');
      Get.snackbar('错误', '扫描设备时出错: ${e.toString()}');
    }
  }

  // 停止扫描
  void stopScan() {
    _bluetoothService.stopScan();
  }

  // 配对并连接设备
  Future<void> pairAndConnectDevice(flutterblue.BluetoothDevice device) async {
    try {
      Get.closeAllSnackbars();
      Get.snackbar('提示', '正在配对并连接设备...');
      final bool success = await _bluetoothService.pairAndConnectDevice(device);
      
      if (success) {
        Get.snackbar('成功', '设备配对并连接成功');
      } else {
        Get.snackbar('错误', '设备配对或连接失败');
      }
      _bluetoothService.devices.refresh(); // 强制刷新
    } catch (e) {
      developer.log(
        'Error during pairing and connecting',
        name: 'BluetoothController',
        error: e.toString(),
      );
      Get.snackbar('错误', '配对连接过程中出现错误: ${e.toString()}');
    }
  }

  // 断开连接
  Future<void> disconnectDevice(flutterblue.BluetoothDevice device) async {
    try {
      Get.closeAllSnackbars();
      Get.snackbar('提示', '正在断开设备连接...');
      await _bluetoothService.disconnectDevice(device);
      Get.snackbar('成功', '设备已断开连接');
      // 强制刷新，确保UI同步
      update();
      // 断开后重新扫描，刷新设备列表
      await startScan();
      _bluetoothService.devices.refresh(); // 强制刷新
    } catch (e) {
      developer.log(
        'Error during disconnect',
        name: 'BluetoothController',
        error: e.toString(),
      );
      Get.snackbar('错误', '断开连接时出现错误: ${e.toString()}');
    }
  }
} 