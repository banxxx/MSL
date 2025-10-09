import 'package:flutter/material.dart';
import 'package:minecraft_server_link/services/settings_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _isLoading = true;

  final List<int> _refreshIntervals = [30, 60, 120, 300];

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // 延迟一帧后设置加载完成，确保 Provider 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                      title: '关于',
                      icon: Icons.info,
                      children: [
                        _buildTapTile(
                          title: '应用说明',
                          subtitle: '查看应用功能与使用指南',
                          icon: Icons.description,
                          onTap: _showAboutDialog,
                        ),
                        _buildTapTile(
                          title: '版本信息',
                          subtitle: _version.isEmpty ? '加载中...' : _version,
                          icon: Icons.info_outline,
                          onTap: null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Text(
                      'Made with ❤️ for Minecraft Players',
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
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          '设置',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(Icons.settings, size: 200, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
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
}