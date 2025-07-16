import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutterblue;
import 'bluetooth_controller.dart';
import 'bluetooth_service.dart';

class BluetoothBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BluetoothService>(() => BluetoothService());
    Get.lazyPut<BluetoothController>(() => BluetoothController());
  }
}

class BluetoothPage extends GetView<BluetoothController> {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备'),
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                  controller.isScanning
                      ? Icons.stop_circle
                      : Icons.play_circle,
                ),
                onPressed: () {
                  if (controller.isScanning) {
                    controller.stopScan();
                  } else {
                    controller.startScan();
                  }
                },
              )),
        ],
      ),
      body: Column(
        children: [
          // 蓝牙状态栏
          Obx(() => Container(
                color: controller.isBluetoothOn ? Colors.green[100] : Colors.red[100],
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: controller.isBluetoothOn ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8.0),
                    Text(
                      controller.isBluetoothOn ? '蓝牙已开启' : '蓝牙未开启',
                      style: TextStyle(
                        color: controller.isBluetoothOn ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              )),
          // 新增：隐藏未知设备开关
          Obx(() => SwitchListTile(
                title: Text('隐藏未知设备'),
                value: controller.hideUnknownDevices.value,
                onChanged: (val) => controller.hideUnknownDevices.value = val,
              )),
          // 设备列表
          Expanded(
            child: Obx(
              () {
                // 先过滤，再排序
                final devices = controller.devices
                    .where((device) => !controller.hideUnknownDevices.value || device.device.platformName.isNotEmpty)
                    .toList();
                devices.sort((a, b) {
                  final aPaired = controller.isDevicePaired(a.device.remoteId.str);
                  final bPaired = controller.isDevicePaired(b.device.remoteId.str);
                  if (aPaired && !bPaired) return -1;
                  if (!aPaired && bPaired) return 1;
                  return 0;
                });
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final deviceId = device.device.remoteId.str;
                    final isConnected = controller.isDeviceConnected(deviceId);
                    final isPaired = controller.isDevicePaired(deviceId);
                    return Card(
                      key: ValueKey(device.device.remoteId.str),
                      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            Icon(
                              Icons.bluetooth,
                              color: Theme.of(context).primaryColor,
                              size: 24.0,
                            ),
                            if (isConnected)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          device.device.platformName.isNotEmpty
                              ? device.device.platformName
                              : '未知设备',
                          style: TextStyle(
                            fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 调试：显示 deviceId 和 isConnected
                            Text('ID: $deviceId, 已连接: $isConnected', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('MAC: 24{device.device.remoteId}'),
                            Text('信号强度: 24{device.rssi} dBm'),
                            if (isPaired)
                              Text(
                                '已配对',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12.0,
                                ),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: isConnected
                              ? () => controller.disconnectDevice(device.device)
                              : () => controller.pairAndConnectDevice(device.device),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected ? Colors.yellow : Colors.blue,
                          ),
                          child: Text(
                            isConnected ? '断开' : '连接',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.white, // 断开为绿色，连接为白色
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 