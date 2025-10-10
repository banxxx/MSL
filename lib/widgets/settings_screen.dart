import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:minecraft_server_link/services/settings_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/mcstatus_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _isLoading = true;

  static const _cardElevation = 0.0;
  // 防抖计时器
  Timer? _debounceTimer;
  // 防抖时间，例如 500 毫秒
  final Duration _debounceDuration = const Duration(milliseconds: 500);
  // 缓存Future，避免重复调用
  late Future<String> _versionFuture;

  // GitHub 仓库信息
  static const String _githubOwner = 'banxxx';
  static const String _githubRepo = 'MSL';
  static const String _githubReleasesApi =
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

  final List<int> _refreshIntervals = [30, 60, 120, 300];

  @override
  void initState() {
    super.initState();
    // 初始化缓存的Future，只在页面初始化时执行一次
    _versionFuture = getAppVersion();
    _loadVersion();
    // 延迟一帧后设置加载完成，确保 Provider 已初始化
    _isLoading = false;
    setState(() {
    });
    if (mounted) {
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
    setState(() {
      _version = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
    }
  }

  Future<void> _showRefreshIntervalDialog(SettingsNotifier settings) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('选择刷新间隔'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _refreshIntervals.map((interval) {
            return RadioListTile<int>(
              title: Text('${interval}秒'),
              value: interval,
              groupValue: settings.refreshInterval,
              activeColor: Colors.green[600],
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      await settings.updateSetting('refresh_interval', selected);
    }
  }

  Future<void> _showAboutDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[300]!, Colors.green[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dns, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('关于应用'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Minecraft Server Link',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本 $_version',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '一个简洁优雅的 Minecraft 服务器状态监控工具。',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '功能特性：',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('实时服务器状态监控'),
            _buildFeatureItem('在线玩家列表查看'),
            _buildFeatureItem('服务器信息展示'),
            _buildFeatureItem('自动刷新功能'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }
    return Consumer<SettingsNotifier>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSection(
                      title: '显示设置',
                      icon: Icons.visibility,
                      children: [
                        _buildSwitchTile(
                          title: '显示玩家数量',
                          subtitle: '在服务器卡片上显示在线玩家数',
                          value: settings.showPlayerCount,
                          onChanged: (value) {
                            settings.updateSetting('show_player_count', value);
                          },
                        ),
                        _buildSwitchTile(
                          title: '显示服务器简介',
                          subtitle: '展开卡片时显示 MOTD 信息',
                          value: settings.showMotd,
                          onChanged: (value) {
                            settings.updateSetting('show_motd', value);
                          },
                        ),
                        _buildSwitchTile(
                          title: '模糊IP地址',
                          subtitle: '使用模糊效果隐藏服务器地址',
                          value: settings.blurIpAddress,
                          onChanged: (value) {
                            settings.updateSetting('blur_ip_address', value);
                          },
                        ),
                      ],
                    ),

                    _buildSection(
                      title: '刷新设置',
                      icon: Icons.refresh,
                      children: [
                        _buildSwitchTile(
                          title: '自动刷新',
                          subtitle: '定期自动更新服务器状态',
                          value: settings.autoRefresh,
                          onChanged: (value) {
                            settings.updateSetting('auto_refresh', value);
                          },
                        ),
                        _buildTapTile(
                          title: '刷新间隔',
                          subtitle: '${settings.refreshInterval} 秒',
                          icon: Icons.timer,
                          enabled: settings.autoRefresh,
                          onTap: settings.autoRefresh ? () => _showRefreshIntervalDialog(settings) : null,
                        ),
                      ],
                    ),

                    _buildSection(
                      title: '交互设置',
                      icon: Icons.touch_app,
                      children: [
                        _buildSwitchTile(
                          title: '触觉反馈',
                          subtitle: '长按编辑时提供震动反馈',
                          value: settings.hapticFeedback,
                          onChanged: (value) {
                            settings.updateSetting('haptic_feedback', value);
                          },
                        ),
                      ],
                    ),

                    _buildSection(
                      title: 'Minetrack 设置',
                      icon: Icons.api,
                      children: [
                        _buildTapTile(
                          title: 'API 地址配置',
                          subtitle: settings.historyServerUrl.isEmpty
                              ? '未配置（点击设置）'
                              : settings.historyServerUrl,
                          icon: Icons.link,
                          onTap: () => _showHistoryUrlDialog(settings),
                        ),
                        if (settings.historyServerUrl.isNotEmpty)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Icon(Icons.check_circle, color: Colors.green[600]),
                            title: const Text(
                              '地址已配置',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            trailing: TextButton(
                              onPressed: () => _clearHistoryUrl(settings),
                              child: const Text('清除'),
                            ),
                          ),
                      ],
                    ),

                    _buildSection(
                      title: '关于',
                      icon: Icons.info,
                      children: [
                        _buildTapTile(
                          title: '应用说明',
                          subtitle: '查看应用功能与使用指南',
                          icon: Icons.description,
                          onTap: _showAboutDialog,
                        ),
                        // 版本信息模块（增加点击功能）
                        _buildVersionInfo(context),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Text(
                      'Made with for Minecraft Players',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.green[600],
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double top = constraints.biggest.height;
          final double collapsedHeight =
              kToolbarHeight + MediaQuery.of(context).padding.top;

          final double opacity = ((top - collapsedHeight) /
              (140 - collapsedHeight)).clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            background: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  right: -30,
                  top: -30,
                  child: Opacity(
                    opacity: 0.1,
                    child: Icon(Icons.settings, size: 200, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 16,
                  child: Opacity(
                    opacity: opacity,
                    child: const Text(
                      '设置',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return _customCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _checkForUpdateDebounced(),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 添加这一行
          leading: Icon(Icons.upload_rounded, color: Colors.green[600]),
          title: const Text('检查更新'),
          subtitle: FutureBuilder<String>(
            future: _versionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Text(
                  '当前版本: ${snapshot.data ?? "未知"}',
                );
              } else {
                return const Text(
                  '正在获取版本号...',
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // 防抖包装函数，用于延迟执行更新检查
  void _checkForUpdateDebounced() {
    // 如果上一个计时器还在运行，就取消它
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    // 设置一个新的计时器
    _debounceTimer = Timer(_debounceDuration, () {
      _checkForUpdate(); // 计时器结束后执行实际的更新检查逻辑，不传递 context
    });
  }

  Widget _customCard({required Widget child, VoidCallback? onTap}) {
    return Card(
      color: Colors.white,
      elevation: _cardElevation,
      shape: RoundedRectangleBorder(
        // 添加圆角
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // 圆角匹配卡片
        onTap: onTap,
        child: child,
      ),
    );
  }

  // 检查更新逻辑 (实际的逻辑，现在由防抖函数调用)
  // 注意：此方法不再接收 BuildContext 参数，而是直接使用 this.context
  void _checkForUpdate() async {
    // 在显示加载指示器前确保 State 仍然挂载
    if (!mounted) return;

    // 显示加载指示器，防止用户疑惑
    showDialog(
      context: context, // 使用 this.context
      barrierDismissible: false, // 不允许点击外部关闭
      builder:
          (ctx) => const AlertDialog(
        // 这里的 ctx 是 dialog 自己的 context，总是安全的
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在检查更新...'),
          ],
        ),
      ),
    );

    try {
      // 首先检查网络连接
      final hasNetwork = await _checkNetworkConnection();
      if (!hasNetwork) {
        // 在关闭加载指示器前确保 State 仍然挂载
        if (!mounted) return;
        Navigator.pop(context); // 关闭加载指示器

        // 在显示错误弹窗前确保 State 仍然挂载
        if (!mounted) return;
        _showErrorDialog(context, '无网络连接，请检查网络设置后重试。');
        return;
      }

      // 获取本地版本和远程版本
      final localVersion = await getAppVersion();
      final latestRelease = await _getLatestReleaseFromGitHub();

      // 在关闭加载指示器前确保 State 仍然挂载
      if (!mounted) return;
      // 关闭加载指示器
      Navigator.pop(context); // 使用 this.context

      if (latestRelease != null) {
        final githubVersion = latestRelease['tag_name'] as String;
        final releaseBody = latestRelease['body'] as String;
        final releaseUrl = latestRelease['html_url'] as String;

        // 在显示弹窗前确保 State 仍然挂载
        if (!mounted) return;
        if (_compareVersions(githubVersion, localVersion) > 0) {
          _showUpdateDialog(
            context, // 使用 this.context
            githubVersion,
            releaseBody,
            releaseUrl,
          );
        } else {
          _showNoUpdateDialog(context); // 使用 this.context
        }
      } else {
        // 在显示错误弹窗前确保 State 仍然挂载
        if (!mounted) return;
        _showErrorDialog(context, '无法获取更新信息，请稍后再试。'); // 使用 this.context
      }
    } on SocketException catch (_) {
      // 网络连接异常
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载指示器
      if (!mounted) return;
      _showErrorDialog(context, '无网络连接，请检查网络设置后重试。');
    } on TimeoutException catch (_) {
      // 请求超时
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载指示器
      if (!mounted) return;
      _showErrorDialog(context, '网络连接超时，请稍后再试。');
    } on HttpException catch (_) {
      // HTTP异常
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载指示器
      if (!mounted) return;
      _showErrorDialog(context, '服务器连接异常，请稍后再试。');
    } catch (e) {
      // 其他异常
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载指示器
      if (!mounted) return;
      _showErrorDialog(
        context,
        '检查更新时发生错误: ${e.toString()}',
      ); // 使用 this.context
    }
  }

  // 从 GitHub API 获取最新发布信息
  Future<Map<String, dynamic>?> _getLatestReleaseFromGitHub() async {
    try {
      final response = await http.get(
        Uri.parse(_githubReleasesApi),
        headers: {'User-Agent': 'Flutter-App'}, // 添加User-Agent头
      ).timeout(const Duration(seconds: 10)); // 设置10秒超时

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 403) {
        // GitHub API 限制
        throw HttpException('GitHub API 请求限制，请稍后再试');
      } else if (response.statusCode == 404) {
        // 仓库不存在或发布不存在
        throw HttpException('未找到发布信息，请检查仓库配置');
      } else {
        // 其他HTTP错误
        throw HttpException('服务器返回错误: ${response.statusCode}');
      }
    } on SocketException catch (_) {
      // 网络连接异常
      throw SocketException('网络连接失败');
    } on TimeoutException catch (_) {
      // 请求超时
      throw TimeoutException('请求超时', const Duration(seconds: 10));
    } on HttpException catch (_) {
      // HTTP异常，重新抛出
      rethrow;
    } catch (e) {
      // 其他异常（如JSON解析错误等）
      throw Exception('数据解析错误: ${e.toString()}');
    }
  }

  // 检查网络连接状态
  Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // 显示错误弹窗
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 显示有可用更新的弹窗
  void _showUpdateDialog(
      BuildContext context,
      String githubVersion,
      String releaseBody,
      String releaseUrl,
      ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        title: Text('发现新版本：$githubVersion'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('更新内容：'),
              const SizedBox(height: 8),
              Text(releaseBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭弹窗
              _launchUrl(releaseUrl); // 打开 GitHub 发布页面
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  // 打开 URL
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('无法打开: $url');
    }
  }

  // 显示没有可用更新的弹窗
  void _showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text('已是最新版本'),
        content: const Text('当前已安装最新版本的应用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 比较两个版本字符串（简单比较，复杂版本需调整，已处理 'v' 前缀）
  // 返回 > 0 如果 version1 较新，< 0 如果 version2 较新，0 如果相同。
  int _compareVersions(String version1, String version2) {
    // 移除版本号开头的 'v'，如果存在的话
    final cleanVersion1 =
    version1.startsWith('v') ? version1.substring(1) : version1;
    final cleanVersion2 =
    version2.startsWith('v') ? version2.substring(1) : version2;

    final v1Parts = cleanVersion1.split('.').map(int.parse).toList();
    final v2Parts = cleanVersion2.split('.').map(int.parse).toList();

    for (int i = 0; i < v1Parts.length; i++) {
      if (i >= v2Parts.length) return 1; // v1 有更多部分，因此更新
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    if (v2Parts.length > v1Parts.length) return -1; // v2 有更多部分，因此更新
    return 0; // 版本号相同
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green[600],
      ),
    );
  }

  Widget _buildTapTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      enabled: enabled,
      leading: Icon(
        icon,
        color: enabled ? Colors.green[600] : Colors.grey[400],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: enabled ? Colors.black87 : Colors.grey[400],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: enabled ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      trailing: onTap != null
          ? Icon(
        Icons.chevron_right,
        color: enabled ? Colors.grey[400] : Colors.grey[300],
      )
          : null,
      onTap: onTap,
    );
  }

  // 异步获取应用版本信息
  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version; // 返回版本号
  }

  Future<void> _showHistoryUrlDialog(SettingsNotifier settings) async {
    final controller = TextEditingController(text: settings.historyServerUrl);
    bool isValidating = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('配置 Minetrack API 地址'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '请输入完整的 API 地址',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '例如: https://example.com/api',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                enabled: !isValidating,
                decoration: InputDecoration(
                  hintText: 'https://your-domain.com/api',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              if (isValidating)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '正在验证连接...',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isValidating ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isValidating
                  ? null
                  : () async {
                final url = controller.text.trim();

                if (url.isEmpty) {
                  Navigator.pop(context, '');
                  return;
                }

                setState(() {
                  isValidating = true;
                });

                try {
                  final isValid = await MCStatusService.validateApiUrl(url);

                  if (!context.mounted) return;

                  if (isValid) {
                    Navigator.pop(context, url);
                  } else {
                    setState(() {
                      isValidating = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('无法连接到该地址，请检查 URL 是否正确'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;

                  setState(() {
                    isValidating = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('验证失败: ${e.toString()}'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isValidating ? Colors.grey : Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await settings.updateSetting('history_server_url', result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(result.isEmpty ? '已清除配置' : '地址配置成功'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _clearHistoryUrl(SettingsNotifier settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('清除配置'),
        content: const Text('确定要清除 Minetrack API 地址配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await settings.updateSetting('history_server_url', '');
    }
  }
}