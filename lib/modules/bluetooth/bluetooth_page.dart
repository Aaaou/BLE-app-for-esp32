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
      body: Obx(
        () => ListView.builder(
          itemCount: controller.devices.length,
          itemBuilder: (context, index) {
            final device = controller.devices[index];
            return ListTile(
              leading: Icon(
                Icons.bluetooth,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                device.device.platformName.isNotEmpty
                    ? device.device.platformName
                    : '未知设备',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAC: ${device.device.remoteId}'),
                  Text('信号强度: ${device.rssi} dBm'),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => controller.connectToDevice(device.device),
                child: const Text('连接'),
              ),
            );
          },
        ),
      ),
    );
  }
} 