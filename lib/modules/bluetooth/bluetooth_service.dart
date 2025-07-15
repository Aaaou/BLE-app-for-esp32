import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutterblue;
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends GetxService {
  // 蓝牙状态
  final RxBool isBluetoothOn = false.obs;
  final RxBool isScanning = false.obs;
  final RxList<flutterblue.ScanResult> devices = <flutterblue.ScanResult>[].obs;

  // 初始化蓝牙服务
  Future<BluetoothService> init() async {
    // 检查蓝牙状态
    flutterblue.FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn.value = state == flutterblue.BluetoothAdapterState.on;
    });

    return this;
  }

  // 请求必要的权限
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // 开始扫描设备
  Future<void> startScan() async {
    if (isScanning.value) return;
    
    // 请求权限
    bool hasPermission = await requestPermissions();
    if (!hasPermission) {
      Get.snackbar('错误', '需要蓝牙和位置权限才能扫描设备');
      return;
    }

    // 清除之前的设备列表
    devices.clear();
    
    // 开始扫描
    isScanning.value = true;
    
    // 监听扫描结果
    flutterblue.FlutterBluePlus.scanResults.listen((results) {
      devices.value = results;
    });

    // 开始扫描，5秒后自动停止
    await flutterblue.FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
      androidUsesFineLocation: true,
    );
    
    // 扫描结束后更新状态
    isScanning.value = false;
  }

  // 停止扫描
  void stopScan() {
    flutterblue.FlutterBluePlus.stopScan();
    isScanning.value = false;
  }

  // 连接设备
  Future<bool> connectToDevice(flutterblue.BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      return true;
    } catch (e) {
      print('连接错误: $e');
      return false;
    }
  }

  // 断开连接
  Future<void> disconnect(flutterblue.BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      print('断开连接错误: $e');
    }
  }

  // 检查设备是否支持BLE
  Future<bool> checkBleSupport() async {
    try {
      return await flutterblue.FlutterBluePlus.isSupported;
    } catch (e) {
      return false;
    }
  }
} 