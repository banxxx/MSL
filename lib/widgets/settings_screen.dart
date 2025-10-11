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
  late final Future<String> _versionFuture;
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  // GitHub 配置
  static const String _githubOwner = 'banxxx';
  static const String _githubRepo = 'MSL';
  static const String _githubReleasesApi =
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';

  static const List<int> _refreshIntervals = [30, 60, 120, 300];

  @override
  void initState() {
    super.initState();
    _versionFuture = _getAppVersion();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> _showRefreshIntervalDialog(SettingsNotifier settings) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => _RefreshIntervalDialog(
        intervals: _refreshIntervals,
        currentInterval: settings.refreshInterval,
      ),
    );

    if (selected != null) {
      await settings.updateSetting('refresh_interval', selected);
    }
  }

  void _checkForUpdateDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _checkForUpdate);
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;

    _showLoadingDialog();

    try {
      final hasNetwork = await _checkNetworkConnection();
      if (!hasNetwork) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorDialog('无网络连接，请检查网络设置后重试。');
        return;
      }

      final localVersion = await _getAppVersion();
      final latestRelease = await _getLatestReleaseFromGitHub();

      if (!mounted) return;
      Navigator.pop(context);

      if (latestRelease != null) {
        final githubVersion = latestRelease['tag_name'] as String;
        final releaseBody = latestRelease['body'] as String;
        final releaseUrl = latestRelease['html_url'] as String;

        if (!mounted) return;
        if (_compareVersions(githubVersion, localVersion) > 0) {
          _showUpdateDialog(githubVersion, releaseBody, releaseUrl);
        } else {
          _showNoUpdateDialog();
        }
      } else {
        if (!mounted) return;
        _showErrorDialog('无法获取更新信息，请稍后再试。');
      }
    } on SocketException catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('无网络连接，请检查网络设置后重试。');
    } on TimeoutException catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('网络连接超时，请稍后再试。');
    } on HttpException catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('服务器连接异常，请稍后再试。');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog('检查更新时发生错误: ${e.toString()}');
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LoadingDialog(message: '正在检查更新...'),
    );
  }

  Future<Map<String, dynamic>?> _getLatestReleaseFromGitHub() async {
    try {
      final response = await http.get(
        Uri.parse(_githubReleasesApi),
        headers: {'User-Agent': 'Flutter-App'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 403) {
        throw HttpException('GitHub API 请求限制，请稍后再试');
      } else if (response.statusCode == 404) {
        throw HttpException('未找到发布信息，请检查仓库配置');
      } else {
        throw HttpException('服务器返回错误: ${response.statusCode}');
      }
    } on SocketException catch (_) {
      throw SocketException('网络连接失败');
    } on TimeoutException catch (_) {
      throw TimeoutException('请求超时', const Duration(seconds: 10));
    } on HttpException catch (_) {
      rethrow;
    } catch (e) {
      throw Exception('数据解析错误: ${e.toString()}');
    }
  }

  Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => _MessageDialog(
        title: '错误',
        message: message,
        icon: Icons.error_outline,
        iconColor: Colors.red,
      ),
    );
  }

  void _showUpdateDialog(String version, String releaseBody, String releaseUrl) {
    showDialog(
      context: context,
      builder: (context) => _UpdateAvailableDialog(
        version: version,
        releaseBody: releaseBody,
        releaseUrl: releaseUrl,
      ),
    );
  }

  void _showNoUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => const _MessageDialog(
        title: '已是最新版本',
        message: '当前已安装最新版本的应用。',
        icon: Icons.check_circle,
        iconColor: Colors.green,
      ),
    );
  }

  int _compareVersions(String version1, String version2) {
    final cleanVersion1 = version1.startsWith('v') ? version1.substring(1) : version1;
    final cleanVersion2 = version2.startsWith('v') ? version2.substring(1) : version2;

    final v1Parts = cleanVersion1.split('.').map(int.parse).toList();
    final v2Parts = cleanVersion2.split('.').map(int.parse).toList();

    for (int i = 0; i < v1Parts.length; i++) {
      if (i >= v2Parts.length) return 1;
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    if (v2Parts.length > v1Parts.length) return -1;
    return 0;
  }

  Future<void> _showHistoryUrlDialog(SettingsNotifier settings) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _HistoryUrlDialog(
        currentUrl: settings.historyServerUrl,
      ),
    );

    if (result != null) {
      await settings.updateSetting('history_server_url', result);
      if (mounted) {
        _showSnackBar(
          result.isEmpty ? '已清除配置' : '地址配置成功',
          Icons.check_circle,
          Colors.green[600]!,
        );
      }
    }
  }

  Future<void> _clearHistoryUrl(SettingsNotifier settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmDialog(
        title: '清除配置',
        message: '确定要清除 Minetrack API 地址配置吗？',
      ),
    );

    if (confirmed == true) {
      await settings.updateSetting('history_server_url', '');
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            slivers: [
              const _SettingsAppBar(),
              SliverPadding(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DisplaySection(settings: settings),
                    _RefreshSection(
                      settings: settings,
                      onIntervalTap: () => _showRefreshIntervalDialog(settings),
                    ),
                    _InteractionSection(settings: settings),
                    _MinetrackSection(
                      settings: settings,
                      onUrlTap: () => _showHistoryUrlDialog(settings),
                      onClearTap: () => _clearHistoryUrl(settings),
                    ),
                    _AboutSection(
                      versionFuture: _versionFuture,
                      onCheckUpdate: _checkForUpdateDebounced,
                      onShowAbout: () => _showAboutDialog(context),
                    ),
                    const SizedBox(height: 16),
                    const _Footer(),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final version = await _versionFuture;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _AboutDialog(version: version),
    );
  }
}

class _SettingsAppBar extends StatelessWidget {
  const _SettingsAppBar();

  @override
  Widget build(BuildContext context) {
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
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
          final opacity = ((top - collapsedHeight) / (140 - collapsedHeight)).clamp(0.0, 1.0);

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
                const Positioned(
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
}

class _DisplaySection extends StatelessWidget {
  final SettingsNotifier settings;

  const _DisplaySection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '显示设置',
      icon: Icons.visibility,
      children: [
        _SettingsSwitchTile(
          title: '显示玩家数量',
          subtitle: '在服务器卡片上显示在线玩家数',
          value: settings.showPlayerCount,
          onChanged: (value) => settings.updateSetting('show_player_count', value),
        ),
        _SettingsSwitchTile(
          title: '显示服务器简介',
          subtitle: '展开卡片时显示 MOTD 信息',
          value: settings.showMotd,
          onChanged: (value) => settings.updateSetting('show_motd', value),
        ),
        _SettingsSwitchTile(
          title: '模糊IP地址',
          subtitle: '使用模糊效果隐藏服务器地址',
          value: settings.blurIpAddress,
          onChanged: (value) => settings.updateSetting('blur_ip_address', value),
        ),
      ],
    );
  }
}

class _RefreshSection extends StatelessWidget {
  final SettingsNotifier settings;
  final VoidCallback onIntervalTap;

  const _RefreshSection({
    required this.settings,
    required this.onIntervalTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '刷新设置',
      icon: Icons.refresh,
      children: [
        _SettingsSwitchTile(
          title: '自动刷新',
          subtitle: '定期自动更新服务器状态',
          value: settings.autoRefresh,
          onChanged: (value) => settings.updateSetting('auto_refresh', value),
        ),
        _SettingsTapTile(
          title: '刷新间隔',
          subtitle: '${settings.refreshInterval} 秒',
          icon: Icons.timer,
          enabled: settings.autoRefresh,
          onTap: settings.autoRefresh ? onIntervalTap : null,
        ),
      ],
    );
  }
}

class _InteractionSection extends StatelessWidget {
  final SettingsNotifier settings;

  const _InteractionSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '交互设置',
      icon: Icons.touch_app,
      children: [
        _SettingsSwitchTile(
          title: '触觉反馈',
          subtitle: '长按编辑时提供震动反馈',
          value: settings.hapticFeedback,
          onChanged: (value) => settings.updateSetting('haptic_feedback', value),
        ),
      ],
    );
  }
}

class _MinetrackSection extends StatelessWidget {
  final SettingsNotifier settings;
  final VoidCallback onUrlTap;
  final VoidCallback onClearTap;

  const _MinetrackSection({
    required this.settings,
    required this.onUrlTap,
    required this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Minetrack 设置',
      icon: Icons.api,
      children: [
        _SettingsTapTile(
          title: 'API 地址配置',
          subtitle: settings.historyServerUrl.isEmpty
              ? '未配置（点击设置）'
              : settings.historyServerUrl,
          icon: Icons.link,
          onTap: onUrlTap,
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
              onPressed: onClearTap,
              child: const Text('清除'),
            ),
          ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final Future<String> versionFuture;
  final VoidCallback onCheckUpdate;
  final VoidCallback onShowAbout;

  const _AboutSection({
    required this.versionFuture,
    required this.onCheckUpdate,
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '关于',
      icon: Icons.info,
      children: [
        _SettingsTapTile(
          title: '应用说明',
          subtitle: '查看应用功能与使用指南',
          icon: Icons.description,
          onTap: onShowAbout,
        ),
        _VersionTile(
          versionFuture: versionFuture,
          onTap: onCheckUpdate,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Made with ❤ for Minecraft Players',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green[600],
      ),
    );
  }
}

class _SettingsTapTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingsTapTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _VersionTile extends StatelessWidget {
  final Future<String> versionFuture;
  final VoidCallback onTap;

  const _VersionTile({
    required this.versionFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.upload_rounded, color: Colors.green[600]),
        title: const Text('检查更新'),
        subtitle: FutureBuilder<String>(
          future: versionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Text('当前版本: ${snapshot.data ?? "未知"}');
            }
            return const Text('正在获取版本号...');
          },
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在检查更新...'),
        ],
      ),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;

  const _MessageDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _RefreshIntervalDialog extends StatelessWidget {
  final List<int> intervals;
  final int currentInterval;

  const _RefreshIntervalDialog({
    required this.intervals,
    required this.currentInterval,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('选择刷新间隔'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: intervals
            .map((interval) => RadioListTile<int>(
          title: Text('$interval秒'),
          value: interval,
          groupValue: currentInterval,
          activeColor: Colors.green[600],
          onChanged: (value) => Navigator.pop(context, value),
        ))
            .toList(),
      ),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  final String version;
  final String releaseBody;
  final String releaseUrl;

  const _UpdateAvailableDialog({
    required this.version,
    required this.releaseBody,
    required this.releaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('发现新版本：$version'),
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
            Navigator.pop(context);
            _launchUrl(releaseUrl);
          },
          child: const Text('立即更新'),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('无法打开: $url');
    }
  }
}

class _HistoryUrlDialog extends StatefulWidget {
  final String currentUrl;

  const _HistoryUrlDialog({required this.currentUrl});

  @override
  State<_HistoryUrlDialog> createState() => _HistoryUrlDialogState();
}

class _HistoryUrlDialogState extends State<_HistoryUrlDialog> {
  late final TextEditingController _controller;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final url = _controller.text.trim();

    if (url.isEmpty) {
      Navigator.pop(context, '');
      return;
    }

    setState(() => _isValidating = true);

    try {
      final isValid = await MCStatusService.validateApiUrl(url);

      if (!mounted) return;

      if (isValid) {
        Navigator.pop(context, url);
      } else {
        setState(() => _isValidating = false);
        _showErrorSnackBar('无法连接到该地址，请检查 URL 是否正确');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isValidating = false);
      _showErrorSnackBar('验证失败: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            controller: _controller,
            enabled: !_isValidating,
            decoration: InputDecoration(
              hintText: 'https://your-domain.com/api',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          if (_isValidating)
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
          onPressed: _isValidating ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isValidating ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isValidating ? Colors.grey : Colors.green[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const _ConfirmDialog({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
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
    );
  }
}

class _AboutDialog extends StatelessWidget {
  final String version;

  const _AboutDialog({required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '版本 $version',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          const Text(
            '一个简洁的 Minecraft 服务器状态监控工具。',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '功能特性：',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('实时服务器状态监控', 1),
          _buildFeatureItem('在线玩家列表查看', 1),
          _buildFeatureItem('服务器信息展示', 1),
          _buildFeatureItem('自动刷新功能', 1),
          const SizedBox(height: 16),
          const Text(
            '使用说明：',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('长按卡片进入编辑模式', 2),
          _buildFeatureItem('点击卡片图片部分查看详情', 2),
          _buildFeatureItem('左滑刷新卡片状态，右滑删除卡片', 2),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text, int index) {
    final iconMap = {
      1: Icons.check_circle,
      2: Icons.error,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            iconMap[index] ?? Icons.help,
            size: 16,
            color: Colors.green[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}