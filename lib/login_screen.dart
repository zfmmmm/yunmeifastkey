import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'info_screen.dart';
import 'http_helper.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('loginUsr') ?? '';
      _passwordController.text = prefs.getString('loginPsw') ?? '';
    });
  }

  // 修改点1：处理自定义请求头
  Map<String, String> _buildHeaders(String? token, String? userId) {
    final headers = <String, String>{
      'x-requested-with': 'XMLHttpRequest',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    if (token != null) headers['token_data'] = token;
    if (userId != null) {
      headers['token_userId'] = userId;
      headers['tokenUserId'] = userId;
    }
    return headers;
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final sess = HttpHelper('https://base.yunmeitech.com/');
      final username = _usernameController.text;
      final password = _passwordController.text;

      // 修改点2：修正MD5处理方式
      final hashedPassword = md5
          .convert(utf8.encode(password))
          .toString()
          .padLeft(32, '0'); // 补齐32位

      // 登录请求
      final loginRes = await sess.post(
        '/login',
        {'userName': username, 'userPwd': hashedPassword},
        headers: _buildHeaders(null, null), // 初始请求不带token
      );

      if (!loginRes['success']) {
        throw Exception(loginRes['msg'] ?? '登录失败');
      }

      final userData = loginRes['o'];
      final token = userData['token'];
      final userId = userData['userId'].toString();

      // 设置用户token和ID
      sess.setToken(token, userId); // 修改点3：添加userId处理

      // 获取学校信息
      final schoolRes = await sess.post('/userschool/getbyuserid', {
        'userId': userId,
      }, headers: _buildHeaders(token, userId));

      if (schoolRes is! List || schoolRes.isEmpty) {
        throw Exception('学校信息获取失败');
      }
      final schoolData = schoolRes[0];

      // 更新服务器地址和学校token
      sess.baseUrl = schoolData['school']['serverUrl'];
      final schoolToken = schoolData['token']; // 修改点4：修正token字段
      final schoolNo = schoolData['schoolNo'];
      sess.setToken(schoolToken, userId);

      // 获取门锁信息
      final lockRes = await sess.post('/dormuser/getuserlock', {
        'schoolNo': schoolNo,
      }, headers: _buildHeaders(schoolToken, userId));

      if (lockRes is! List || lockRes.isEmpty) {
        throw Exception('门锁信息获取失败');
      }
      final lockData = lockRes[0];

      // 保存数据到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('name', userData['realName']);
      await prefs.setString('tel', userData['userTel']);
      await prefs.setString('area', lockData['areaName']);
      await prefs.setString('areaNo', lockData['areaNo']);
      await prefs.setString('build', lockData['buildName']);
      await prefs.setString('buildNo', lockData['buildNo']);
      await prefs.setString('school', lockData['schoolName']);
      await prefs.setString('schoolNo', lockData['schoolNo']);
      await prefs.setString('dorm', lockData['dormName']);
      await prefs.setString('dormNo', lockData['dormNo']);
      await prefs.setString('lockNo', lockData['lockNo']);
      await prefs.setString('lockSec', lockData['lockSecret']);
      await prefs.setString('LUUID', lockData['lockServiceUuid']);
      await prefs.setString('SUUID', lockData['lockCharacterUuid']);
      await prefs.setString('LMAC', lockData['lockNo']);
      await prefs.setString('loginUsr', username);
      await prefs.setString('loginPsw', password);

      if (mounted) {
        // Navigator.pushNamedAndRemoveUntil(
        //   context,
        //   '/login', // 跳转到 LoginScreen 的路由名称
        //   (route) => route.settings.name == '/home', // 只保留 HomeScreen
        // );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InfoScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '登录失败: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color.fromARGB(255, 146, 135, 231);

    return PopScope(
      canPop: true, // 允许返回键生效
      onPopInvoked: (didPop) {
        if (didPop) {
          // 如果返回键被触发（即 didPop 为 true），无需额外处理
          return;
        }
        // 如果需要自定义逻辑，可以在这里添加
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withOpacity(0.5),
                themeColor.withOpacity(0.2),
              ],
            ),
          ),
          child: SafeArea(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      ),
                    )
                    : Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Card(
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '登录',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                      hintText: '请输入手机号',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.phone_rounded,
                                        color: themeColor,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: themeColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      hintText: '请输入密码',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.key_rounded,
                                        color: themeColor,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: themeColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 50,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                    ),
                                    child: const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
        ),
        appBar: AppBar(
          title: const Text(
            '登录',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: themeColor, // 透明背景，与渐变融合
          elevation: 0, // 无阴影
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
