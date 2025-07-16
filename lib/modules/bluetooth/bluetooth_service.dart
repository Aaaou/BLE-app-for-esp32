import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutterblue;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:developer' as developer;

class BluetoothService extends GetxService {
  // 蓝牙状态
  final RxBool isBluetoothOn = false.obs;
  final RxBool isScanning = false.obs;
  final RxList<flutterblue.ScanResult> devices = <flutterblue.ScanResult>[].obs;
  final RxList<flutterblue.BluetoothDevice> bondedDevices = <flutterblue.BluetoothDevice>[].obs;
  
  // 连接状态
  final RxMap<String, bool> deviceConnectionStates = <String, bool>{}.obs;
  
  // 扫描监听器
  StreamSubscription<List<flutterblue.ScanResult>>? _scanSubscription;
  StreamSubscription<flutterblue.BluetoothAdapterState>? _adapterStateSubscription;
  final Map<String, StreamSubscription> _connectionStateSubscriptions = {};
  
  // 连接操作锁
  final Map<String, bool> _connectionLocks = {};
  bool _globalConnectionLock = false;

  // 存储设备的服务和特征值信息
  final Map<String, List<flutterblue.BluetoothService>> _deviceServices = {};

  @override
  void onInit() {
    super.onInit();
    _initBluetooth();
    _updateBondedDevices();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    // 取消所有连接状态监听
    for (var subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    _connectionStateSubscriptions.clear();
    super.onClose();
  }

  // 初始化蓝牙服务
  Future<void> _initBluetooth() async {
    // 检查蓝牙状态
    _adapterStateSubscription = flutterblue.FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn.value = state == flutterblue.BluetoothAdapterState.on;
      if (!isBluetoothOn.value) {
        // 蓝牙关闭时，清除所有连接状态
        deviceConnectionStates.clear();
        _deviceServices.clear();
        _cleanupAllSubscriptions();
      }
    });
  }

  // 更新已配对设备列表
  Future<void> _updateBondedDevices() async {
    try {
      final systemDevices = await flutterblue.FlutterBluePlus.systemDevices([]);
      bondedDevices.value = systemDevices;
    } catch (e) {
      developer.log(
        'Error updating bonded devices',
        name: 'BluetoothService',
        error: e.toString(),
      );
    }
  }

  // 请求必要的权限
  Future<bool> requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> currentStatus = {
        Permission.bluetooth: await Permission.bluetooth.status,
        Permission.bluetoothScan: await Permission.bluetoothScan.status,
        Permission.bluetoothConnect: await Permission.bluetoothConnect.status,
        Permission.location: await Permission.location.status,
      };

      // 检查是否所有权限都已授权
      bool allGranted = currentStatus.values.every((status) => 
        status.isGranted || status.isLimited);
      
      if (allGranted) return true;

      // 只请求未授权的权限
      List<Permission> permissionsToRequest = currentStatus.entries
          .where((entry) => !entry.value.isGranted && !entry.value.isLimited)
          .map((entry) => entry.key)
          .toList();

      if (permissionsToRequest.isEmpty) return true;

      // 请求缺失的权限
      Map<Permission, PermissionStatus> results = await permissionsToRequest.request();
      
      return results.values.every((status) => status.isGranted || status.isLimited);
    } catch (e) {
      developer.log(
        'Error checking permissions',
        name: 'BluetoothService',
        error: e.toString(),
      );
      return false;
    }
  }

  // 开始扫描设备
  Future<void> startScan() async {
    if (isScanning.value) return;
    
    try {
      isScanning.value = true;
      devices.clear();
      
      await flutterblue.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
      
      _scanSubscription = flutterblue.FlutterBluePlus.scanResults.listen(
        (results) {
          devices.value = results;
        },
        onError: (error) {
          developer.log(
            'Scan error',
            name: 'BluetoothService',
            error: error.toString(),
          );
        },
      );
    } catch (e) {
      developer.log(
        'Error starting scan',
        name: 'BluetoothService',
        error: e.toString(),
      );
    }
  }

  // 停止扫描
  void stopScan() {
    if (!isScanning.value) return;
    
    flutterblue.FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    isScanning.value = false;
  }

  // 配对并连接设备
  Future<bool> pairAndConnectDevice(flutterblue.BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    
    if (_globalConnectionLock || _connectionLocks[deviceId] == true) {
      developer.log(
        'Connection already in progress',
        name: 'BluetoothService',
        error: {'device': deviceId},
      );
      return false;
    }
    
    _globalConnectionLock = true;
    _connectionLocks[deviceId] = true;
    
    try {
      developer.log(
        'Starting connection process',
        name: 'BluetoothService',
        error: {'device': deviceId},
      );

      // 断开现有连接
      await _disconnectAllDevices();
      await Future.delayed(const Duration(seconds: 1));
      
      // 连接设备
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      
      // 等待连接状态确认
      bool isConnected = false;
      for (int i = 0; i < 5; i++) {
        final state = await device.connectionState.first;
        if (state == flutterblue.BluetoothConnectionState.connected) {
          isConnected = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!isConnected) {
        throw Exception('Connection verification failed');
      }

      developer.log(
        'Device connected successfully',
        name: 'BluetoothService',
        error: {'device': deviceId},
      );
      
      // 设置MTU
      try {
        final mtu = await device.requestMtu(512);
        developer.log(
          'MTU set successfully',
          name: 'BluetoothService',
          error: {
            'device': deviceId,
            'mtu': mtu,
          },
        );
      } catch (e) {
        developer.log(
          'Failed to set MTU',
          name: 'BluetoothService',
          error: {
            'device': deviceId,
            'error': e.toString(),
          },
        );
        // 继续执行，因为MTU设置失败不是致命错误
      }
      
      // 发现服务
      final services = await device.discoverServices();
      _deviceServices[deviceId] = services;

      // 记录发现的服务
      for (var service in services) {
        developer.log(
          'Service discovered',
          name: 'BluetoothService',
          error: {
            'device': deviceId,
            'service_uuid': service.uuid.toString(),
            'characteristics': service.characteristics.map((c) => c.uuid.toString()).toList(),
          },
        );
      }
      
      deviceConnectionStates[deviceId] = true;
      _startListeningToConnectionState(device);

      // 设置通知
      await _setupNotifications(device, services);
      
      return true;
    } catch (e) {
      developer.log(
        'Connection error',
        name: 'BluetoothService',
        error: {
          'device': deviceId,
          'error': e.toString(),
        },
      );
      
      deviceConnectionStates[deviceId] = false;
      _deviceServices.remove(deviceId);
      
      return false;
    } finally {
      _connectionLocks.remove(deviceId);
      _globalConnectionLock = false;
    }
  }

  // 设置通知
  Future<void> _setupNotifications(
    flutterblue.BluetoothDevice device,
    List<flutterblue.BluetoothService> services,
  ) async {
    final deviceId = device.remoteId.str;
    
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          try {
            await characteristic.setNotifyValue(true);
            
            // 写入描述符
            for (var descriptor in characteristic.descriptors) {
              if (descriptor.uuid.toString().toUpperCase().contains('2902')) {
                await descriptor.write([0x01, 0x00]);
                
                developer.log(
                  'Notification enabled',
                  name: 'BluetoothService',
                  error: {
                    'device': deviceId,
                    'characteristic': characteristic.uuid.toString(),
                    'descriptor': descriptor.uuid.toString(),
                  },
                );
              }
            }
            
            // 设置通知监听
            characteristic.value.listen(
              (value) {
                developer.log(
                  'Notification received',
                  name: 'BluetoothService',
                  error: {
                    'device': deviceId,
                    'characteristic': characteristic.uuid.toString(),
                    'value': value.toString(),
                  },
                );
              },
              onError: (error) {
                developer.log(
                  'Notification error',
                  name: 'BluetoothService',
                  error: {
                    'device': deviceId,
                    'characteristic': characteristic.uuid.toString(),
                    'error': error.toString(),
                  },
                );
              },
            );
          } catch (e) {
            developer.log(
              'Failed to enable notification',
              name: 'BluetoothService',
              error: {
                'device': deviceId,
                'characteristic': characteristic.uuid.toString(),
                'error': e.toString(),
              },
            );
          }
        }
      }
    }
  }

  // 断开设备连接
  Future<void> disconnectDevice(flutterblue.BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    
    try {
      _connectionLocks[deviceId] = true;
      await device.disconnect();
      
      deviceConnectionStates[deviceId] = false;
      _deviceServices.remove(deviceId);
      // 强制刷新，确保 UI 及时更新
      deviceConnectionStates.refresh();
    } catch (e) {
      developer.log(
        'Error during disconnect',
        name: 'BluetoothService',
        error: {
          'device': deviceId,
          'error': e.toString(),
        },
      );
    } finally {
      _connectionLocks.remove(deviceId);
    }
  }

  // 断开所有设备
  Future<void> _disconnectAllDevices() async {
    final connectedDevices = await flutterblue.FlutterBluePlus.connectedSystemDevices;
    
    for (var device in connectedDevices) {
      await disconnectDevice(device);
    }
  }

  // 监听设备连接状态
  void _startListeningToConnectionState(flutterblue.BluetoothDevice device) {
    final deviceId = device.remoteId.str;
    
    _connectionStateSubscriptions[deviceId]?.cancel();
    
    _connectionStateSubscriptions[deviceId] = device.connectionState.listen(
      (state) async {
        final bool isConnected = state == flutterblue.BluetoothConnectionState.connected;
        deviceConnectionStates[deviceId] = isConnected;
        
        if (!isConnected) {
          _deviceServices.remove(deviceId);
        }
      },
      onError: (error) {
        developer.log(
          'Error in connection state stream',
          name: 'BluetoothService',
          error: {
            'device': deviceId,
            'error': error.toString(),
          },
        );
        deviceConnectionStates[deviceId] = false;
        _deviceServices.remove(deviceId);
      },
    );
  }

  // 检查设备连接状态
  bool isDeviceConnected(String deviceId) {
    return deviceConnectionStates[deviceId] ?? false;
  }
  
  // 检查设备配对状态
  bool isDevicePaired(String deviceId) {
    return bondedDevices.any((device) => device.remoteId.str == deviceId);
  }

  // 检查是否可以发送数据
  bool canSendData(String deviceId) {
    return isDeviceConnected(deviceId);
  }

  // 清理所有订阅
  void _cleanupAllSubscriptions() {
    for (var subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    _connectionStateSubscriptions.clear();
  }

  // 检查BLE支持
  Future<bool> checkBleSupport() async {
    try {
      return await flutterblue.FlutterBluePlus.isSupported;
    } catch (e) {
      developer.log(
        'Error checking BLE support',
        name: 'BluetoothService',
        error: e.toString(),
      );
      return false;
    }
  }
} 