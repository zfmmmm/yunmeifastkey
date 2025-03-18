import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'main.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String _infoText = '加载中...';
  bool _autoOpenDoor = false; // 开关状态
  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadAutoOpenSetting(); // 确保加载开关设置
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    StringBuffer sb = StringBuffer();
    sb.writeln('姓名：${prefs.getString('name') ?? '未导入'}');
    // sb.writeln('用户ID：${prefs.getString('userId') ?? '未导入'}');
    sb.writeln('学校：${prefs.getString('school') ?? '未导入'}');
    sb.writeln('区域：${prefs.getString('area') ?? '未导入'}');
    sb.writeln('楼号：${prefs.getString('build') ?? '未导入'} ');
    sb.writeln('房间：${prefs.getString('dorm') ?? '未导入'} ');
    sb.writeln('设备MAC：${prefs.getString('LMAC') ?? '未导入'}');
    // sb.writeln('锁UUID：${prefs.getString('LUUID') ?? '未导入'}');
    // sb.writeln('服务UUID：${prefs.getString('SUUID') ?? '未导入'}');
    // sb.writeln('上次定位：${prefs.getString('lstLoca') ?? '从未定位'}');

    setState(() {
      _infoText = sb.toString();
    });
  }

  // 加载自动开门设置
  Future<void> _loadAutoOpenSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoOpenDoor = prefs.getBool('autoOpenDoor') ?? false; // 默认关闭
    });
  }

  // 保存自动开门设置
  Future<void> _saveAutoOpenSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoOpenDoor', value);
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定要退出登录吗？所有本地用户信息将被清除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loginUsr');
      await prefs.remove('loginPsw');
      await prefs.remove('userId');
      await prefs.remove('name');
      await prefs.remove('tel');
      await prefs.remove('area');
      await prefs.remove('areaNo');
      await prefs.remove('build');
      await prefs.remove('buildNo');
      await prefs.remove('school');
      await prefs.remove('schoolNo');
      await prefs.remove('dorm');
      await prefs.remove('dormNo');
      await prefs.remove('lockNo');
      await prefs.remove('lockSec');
      await prefs.remove('LUUID');
      await prefs.remove('SUUID');
      await prefs.remove('LMAC');
      await prefs.remove('lstLoca');

      if (mounted) {
        // 跳转到 LoginScreen 并移除 InfoScreen，但保留 DoorOpenerScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止默认的返回行为
      onPopInvoked: (didPop) {
        // 拦截返回键，直接跳转到主页面
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home', // 跳转到主界面
          (route) => false, // 移除所有其他页面
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('用户信息')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_infoText, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('打开应用时自动开锁', style: TextStyle(fontSize: 16)),
                    Switch(
                      value: _autoOpenDoor,
                      onChanged: (value) {
                        setState(() {
                          _autoOpenDoor = value;
                        });
                        _saveAutoOpenSetting(value); // 保存设置
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: const Color.fromARGB(255, 96, 172, 252),
                      // foregroundColor: const Color.fromARGB(255, 96, 172, 252),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('退出登录'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
