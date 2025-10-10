import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minecraft_server_link/models/server.dart';
import 'package:minecraft_server_link/models/server_status.dart';
import 'package:minecraft_server_link/services/mcstatus_service.dart';
import 'package:minecraft_server_link/services/settings_notifier.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../models/history_data_point.dart';

class ServerDetailScreen extends StatefulWidget {
  final Server server;
  final ServerStatus? initialStatus;

  const ServerDetailScreen({
    super.key,
    required this.server,
    this.initialStatus,
  });

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen>
    with TickerProviderStateMixin {
  late Future<ServerStatus> _statusFuture;
  ServerStatus? _cachedStatus;

  // 刷新动画控制器
  late AnimationController _refreshAnimationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    // 初始化刷新动画控制器
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.initialStatus != null) {
      _cachedStatus = widget.initialStatus;
      _statusFuture = Future.value(widget.initialStatus);
    } else {
      _refreshStatus();
    }
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return; // 防止重复刷新

    setState(() {
      _isRefreshing = true;
    });

    // 开始旋转动画
    _refreshAnimationController.repeat();

    final service = context.read<MCStatusService>();

    try {
      final status = await service.getServerStatusFromServer(widget.server);

      if (mounted) {
        setState(() {
          _statusFuture = Future.value(status);
          _cachedStatus = status;
          _isRefreshing = false;
        });

        // 停止旋转动画
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();

        // 显示成功提示
        _showRefreshSnackBar(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        // 停止旋转动画
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();

        // 显示失败提示
        _showRefreshSnackBar(false);
      }
    }
  }

  void _showRefreshSnackBar(bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(success ? '刷新成功' : '刷新失败'),
          ],
        ),
        backgroundColor: success ? Colors.green[600] : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('已复制$label'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<ServerStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedStatus == null) {
            return _buildLoadingState();
          }

          if (snapshot.hasError && _cachedStatus == null) {
            return _buildErrorState(snapshot.error.toString());
          }

          final status = snapshot.data ?? _cachedStatus!;
          _cachedStatus = status;

          return CustomScrollView(
            slivers: [
              _buildAppBar(status),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusOverview(status),
                      const SizedBox(height: 16),
                      _buildBasicInfo(status),
                      if (status.players != null) ...[
                        const SizedBox(height: 16),
                        _buildPlayersSection(status.players!),
                      ],
                      if (status.motd != null) ...[
                        const SizedBox(height: 16),
                        _buildMotdSection(status.motd!),
                        if (status.online) ...[
                          const SizedBox(height: 16),
                          ServerHistoryChart(
                            serverIp: widget.server.address,
                            port: widget.server.port.toString(),
                            chartColor: Colors.green[600]!,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: Colors.green[600],
            size: 60,
          ),
          const SizedBox(height: 24),
          Text(
            '正在加载服务器信息...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            ),
            const SizedBox(height: 32),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ServerStatus status) {
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.green[600],
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // 刷新按钮带旋转动画
        RotationTransition(
          turns: _refreshAnimationController,
          child: IconButton(
            icon: Icon(
              _isRefreshing ? Icons.sync : Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _isRefreshing ? null : _refreshStatus,
            tooltip: '刷新',
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildServerIcon(status.icon),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.server.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<SettingsNotifier>(
                  builder: (context, settings, child) {
                    return GestureDetector(
                      onTap: () =>
                          _copyToClipboard(widget.server.address, '服务器地址'),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.dns, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              widget.server.address,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerIcon(String? iconData) {
    const size = 100.0;

    if (iconData == null || iconData.isEmpty) {
      return _buildFallbackIcon(size);
    }

    try {
      final bytes = base64Decode(iconData.split(',').last);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
            errorBuilder: (_, __, ___) => _buildFallbackIcon(size),
          ),
        ),
      );
    } catch (e) {
      return _buildFallbackIcon(size);
    }
  }

  Widget _buildFallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[300]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.dns,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatusOverview(ServerStatus status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '服务器状态',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatusChip(
                    icon: status.online ? Icons.check_circle : Icons.cancel,
                    label: status.online ? '在线' : '离线',
                    color: status.online ? Colors.green : Colors.red,
                  ),
                ),
                if (status.online && status.players != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusChip(
                      icon: Icons.people,
                      label: '${status.players!.online}/${status.players!.max}',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(ServerStatus status) {
    final items = <Map<String, dynamic>>[];

    if (status.ipAddress != null) {
      items.add({
        'icon': Icons.location_on,
        'label': 'IP 地址',
        'value': status.ipAddress!,
        'color': Colors.orange,
        'copyable': true,
      });
    }

    if (status.version != null) {
      items.add({
        'icon': Icons.category,
        'label': '服务器版本',
        'value': status.version!,
        'color': Colors.purple,
        'copyable': false,
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '基本信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInfoItem(
                  icon: item['icon'],
                  label: item['label'],
                  value: item['value'],
                  color: item['color'],
                  copyable: item['copyable'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool copyable = false,
  }) {
    return InkWell(
      onTap: copyable ? () => _copyToClipboard(value, label) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (copyable) Icon(Icons.copy, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection(Players players) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '在线玩家',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${players.online}/${players.max}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            if (players.list != null && players.list!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.list!
                    .where((player) => player.name.isNotEmpty)
                    .map((player) => _buildPlayerChip(player))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '暂无玩家在线',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerChip(Player player) {
    return InkWell(
      onTap: () => _copyToClipboard(player.name, '玩家名称'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 6),
            Text(
              player.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotdSection(Motd motd) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '服务器简介 (MOTD)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Text(
                motd.displayText.isEmpty ? '无简介' : motd.displayText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.amber[900],
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}