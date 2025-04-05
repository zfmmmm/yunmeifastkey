import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'info_screen.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yunmei FastKey',
      home: const DoorOpenerScreen(),
      routes: {
        '/home': (context) => const DoorOpenerScreen(),
        '/info': (context) => const InfoScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class DoorOpenerScreen extends StatefulWidget {
  const DoorOpenerScreen({Key? key}) : super(key: key);

  @override
  _DoorOpenerScreenState createState() => _DoorOpenerScreenState();
}

class _DoorOpenerScreenState extends State<DoorOpenerScreen> {
  String? targetDeviceMac;
  Guid? serviceUuid;
  Guid? characteristicUuid;
  String? lockSecret;
  Uint8List? openDoorCommand;
  String locationText = '加载中...';
  bool _autoOpenDoor = false;
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isProcessing = false;
  static bool hasOpenedOnce = false;
  static bool _isFirstConnectionDone = false; // 确保首次连接只执行一次

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.setLogLevel(LogLevel.verbose);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadDeviceInfo();
    await _requestPermissions();
    await _checkFirstLaunch();

    if (!_isFirstConnectionDone) {
      _isFirstConnectionDone = true;
      if (targetDeviceMac != null &&
          serviceUuid != null &&
          characteristicUuid != null &&
          lockSecret != null) {
        await _connectInBackground();
      }
    }
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      targetDeviceMac = prefs.getString('LMAC');
      serviceUuid =
          prefs.getString('LUUID') != null
              ? Guid(prefs.getString('LUUID')!)
              : null;
      characteristicUuid =
          prefs.getString('SUUID') != null
              ? Guid(prefs.getString('SUUID')!)
              : null;
      lockSecret = prefs.getString('lockSec');
      locationText =
          '${prefs.getString('build') ?? '未导入门锁'} ${prefs.getString('dorm') ?? ''}';
      _autoOpenDoor = prefs.getBool('autoOpenDoor') ?? false;
    });

    if (targetDeviceMac == null ||
        serviceUuid == null ||
        characteristicUuid == null ||
        lockSecret == null) {
      _showSnackBar('请先登录以获取设备信息');
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (isFirstLaunch) {
      _showInstructionsDialog();
      await prefs.setBool('isFirstLaunch', false);
    }
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('使用说明'),
          content: const SingleChildScrollView(
            child: Text(
              '欢迎使用云莓闪开！\n\n'
              '1. 请确保设备蓝牙已开启。\n'
              '2. 授予应用蓝牙和位置权限。\n'
              '3. 点击“开门”按钮即可开门。\n'
              '4. 使用时提前将应用打开挂在后台，可做到“无缝开门”，不使用时请把该应用后台杀掉，能获得较好使用体验。\n'
              '5. 如有问题，请联系支持：zfm1419487879@gmail.com。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

    if (!statuses[Permission.bluetoothConnect]!.isGranted ||
        !statuses[Permission.bluetoothScan]!.isGranted ||
        !statuses[Permission.location]!.isGranted) {
      _showSnackBar('请授予蓝牙和位置权限');
      await Future.delayed(const Duration(seconds: 2));
      openAppSettings();
    }
  }

  Future<bool> _checkBluetooth() async {
    if (!await FlutterBluePlus.isSupported) {
      _showSnackBar('设备不支持蓝牙');
      return false;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _showSnackBar('请开启蓝牙');
      return false;
    }
    return true;
  }

  Future<void> _resetBluetooth() async {
    try {
      await FlutterBluePlus.stopScan();
      if (targetDevice != null) await targetDevice!.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {}
  }

  Future<void> _discoverServicesAndCharacteristics() async {
    if (targetDevice == null ||
        serviceUuid == null ||
        characteristicUuid == null)
      return;
    try {
      List<BluetoothService> services = await targetDevice!.discoverServices();
      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == characteristicUuid) {
              targetCharacteristic = characteristic;
              return;
            }
          }
        }
      }
      targetCharacteristic = null;
    } catch (e) {
      targetCharacteristic = null;
    }
  }

  Future<void> _connectInBackground() async {
    if (!(await _checkBluetooth())) return;
    if (targetDeviceMac == null) return;

    await _resetBluetooth();
    await Future.delayed(const Duration(milliseconds: 500));
    targetDevice = BluetoothDevice(
      remoteId: DeviceIdentifier(targetDeviceMac!),
    );

    while (targetDevice != null &&
        await targetDevice!.state.first != BluetoothConnectionState.connected) {
      try {
        await targetDevice!.connect();
        await _discoverServicesAndCharacteristics();
        if (targetCharacteristic != null) {
          _showSnackBar('设备已连接并准备就绪');
          if (_autoOpenDoor && !hasOpenedOnce) {
            await _sendOpenDoorCommand();
            hasOpenedOnce = true;
          }
          break;
        } else {
          await targetDevice!.disconnect();
          targetDevice = null;
          break;
        }
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _connectToDevice() async {
    if (targetDevice != null &&
        await targetDevice!.state.first == BluetoothConnectionState.connected) {
      return;
    }
    if (targetDeviceMac == null) {
      _showSnackBar('请先登录以获取门锁信息');
      return;
    }

    await _resetBluetooth();
    targetDevice = BluetoothDevice(
      remoteId: DeviceIdentifier(targetDeviceMac!),
    );

    for (int i = 0; i < 3; i++) {
      try {
        await targetDevice!.connect(timeout: const Duration(seconds: 15));
        await _discoverServicesAndCharacteristics();
        if (targetCharacteristic != null) {
          _showSnackBar('连接成功');
          return;
        } else {
          await targetDevice!.disconnect();
          targetDevice = null;
        }
      } catch (e) {
        _showSnackBar('第 ${i + 1} 次连接失败: $e');
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          _showSnackBar('连接失败，已重试3次');
          targetDevice = null;
          targetCharacteristic = null;
        }
      }
    }
  }

  Future<void> _sendOpenDoorCommand() async {
    if (lockSecret == null) {
      _showSnackBar('请先登录以获取门锁信息');
      return;
    }

    if (targetCharacteristic == null) {
      _showSnackBar('设备未准备好，正在连接...');
      await _connectToDevice();
      if (targetCharacteristic == null) return;
    }

    try {
      openDoorCommand = generatePassword(lockSecret!);
      await targetCharacteristic!.write(
        openDoorCommand!,
        withoutResponse: true,
      );
      _showSnackBar('开门命令已发送');
      await _disconnectFromDevice();
    } catch (e) {
      _showSnackBar('发送失败: $e');
      await _connectToDevice();
    }
  }

  Future<void> _disconnectFromDevice() async {
    if (targetDevice != null) {
      await targetDevice!.disconnect();
      targetDevice = null;
      targetCharacteristic = null;
      _showSnackBar('已断开连接');
    }
  }

  Future<void> openDoor() async {
    if (isProcessing) return;
    setState(() => isProcessing = true);
    await _sendOpenDoorCommand();
    setState(() => isProcessing = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _navigateToLoginOrInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final loginUsr = prefs.getString('loginUsr');
    if (loginUsr == null || loginUsr.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      ).then((_) => _loadDeviceInfo());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InfoScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          locationText,
          style: const TextStyle(fontSize: 20, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _navigateToLoginOrInfo,
            tooltip: '登录或查看信息',
          ),
        ],
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child:
              isProcessing
                  ? Container(
                    key: const ValueKey('loading'),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 6),
                    ),
                  )
                  : SizedBox(
                    key: const ValueKey('button'),
                    width: 1.618 * 100,
                    height: 1 * 100,
                    child: ElevatedButton(
                      onPressed: openDoor,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        textStyle: const TextStyle(fontSize: 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      child: const Text('开门'),
                    ),
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    targetDevice?.disconnect();
    super.dispose();
  }
}

Uint8List generatePassword(String secret) {
  final bos = BytesBuilder();

  // Write fixed byte 208
  bos.addByte(208);

  // Calculate length: secret.length + 14 (consistent with Java code)
  int len = secret.length + 14;
  bos.addByte(len);

  // Write secret bytes
  final secretBytes = secret.codeUnits;
  for (var byte in secretBytes) {
    bos.addByte(byte);
  }

  // Write fixed byte 165
  bos.addByte(165);

  // Generate 6-digit random number (0 to 999999)
  final random = Random();
  int pw = random.nextInt(1000000);

  // Write each digit of pw (low to high)
  for (int i = 0; i < 6; i++) {
    int digit = pw % 10;
    bos.addByte(digit);
    pw ~/= 10;
  }

  // Write fixed byte sequence: 73, 68, 48, 49 (ASCII "ID01")
  bos.addByte(73);
  bos.addByte(68);
  bos.addByte(48);
  bos.addByte(49);

  // Write fixed byte 167
  bos.addByte(167);

  return bos.toBytes();
}
