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

class _DetailConstants {
  static const double expandedHeight = 240.0;
  static const double iconSize = 100.0;
  static const double cardPadding = 20.0;
  static const double sectionSpacing = 16.0;
  static const Duration refreshDuration = Duration(milliseconds: 800);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chipBorderRadius = BorderRadius.all(Radius.circular(12));

  static BoxShadow iconShadow = BoxShadow(
    color: Colors.black.withOpacity(0.2),
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
}

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
  late AnimationController _refreshAnimationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _refreshAnimationController = AnimationController(
      duration: _DetailConstants.refreshDuration,
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
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
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

        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
        _showRefreshSnackBar(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
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
        shape: RoundedRectangleBorder(borderRadius: _DetailConstants.chipBorderRadius),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        duration: _DetailConstants.snackBarDuration,
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
        shape: RoundedRectangleBorder(borderRadius: _DetailConstants.chipBorderRadius),
        margin: const EdgeInsets.all(16),
        duration: _DetailConstants.snackBarDuration,
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
            return const _LoadingState();
          }

          if (snapshot.hasError && _cachedStatus == null) {
            return _ErrorState(error: snapshot.error.toString());
          }

          final status = snapshot.data ?? _cachedStatus!;
          _cachedStatus = status;

          return CustomScrollView(
            slivers: [
              _AppBarSection(
                server: widget.server,
                status: status,
                isRefreshing: _isRefreshing,
                refreshController: _refreshAnimationController,
                onRefresh: _refreshStatus,
                onCopy: _copyToClipboard,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ContentSection(
                    server: widget.server,
                    status: status,
                    onCopy: _copyToClipboard,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 加载状态组件
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// 错误状态组件
class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                shape: RoundedRectangleBorder(borderRadius: _DetailConstants.chipBorderRadius),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AppBar 部分
class _AppBarSection extends StatelessWidget {
  final Server server;
  final ServerStatus status;
  final bool isRefreshing;
  final AnimationController refreshController;
  final VoidCallback onRefresh;
  final void Function(String, String) onCopy;

  const _AppBarSection({
    required this.server,
    required this.status,
    required this.isRefreshing,
    required this.refreshController,
    required this.onRefresh,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: _DetailConstants.expandedHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.green[600],
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        RotationTransition(
          turns: refreshController,
          child: IconButton(
            icon: Icon(
              isRefreshing ? Icons.sync : Icons.refresh,
              color: Colors.white,
            ),
            onPressed: isRefreshing ? null : onRefresh,
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
                _ServerIcon(iconData: status.icon),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    server.name,
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
                _ServerAddressChip(
                  address: server.address,
                  onCopy: () => onCopy(server.address, '服务器地址'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 服务器图标组件
class _ServerIcon extends StatelessWidget {
  final String? iconData;

  const _ServerIcon({this.iconData});

  @override
  Widget build(BuildContext context) {
    if (iconData == null || iconData!.isEmpty) {
      return _FallbackIcon();
    }

    try {
      final bytes = base64Decode(iconData!.split(',').last);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [_DetailConstants.iconShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            width: _DetailConstants.iconSize,
            height: _DetailConstants.iconSize,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: (_DetailConstants.iconSize * MediaQuery.of(context).devicePixelRatio).round(),
            errorBuilder: (_, __, ___) => _FallbackIcon(),
          ),
        ),
      );
    } catch (e) {
      return _FallbackIcon();
    }
  }
}

class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DetailConstants.iconSize,
      height: _DetailConstants.iconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[300]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_DetailConstants.iconShadow],
      ),
      child: Icon(
        Icons.dns,
        size: _DetailConstants.iconSize * 0.5,
        color: Colors.white,
      ),
    );
  }
}

// 地址芯片组件
class _ServerAddressChip extends StatelessWidget {
  final String address;
  final VoidCallback onCopy;

  const _ServerAddressChip({
    required this.address,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, settings, child) {
        return GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  address,
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
    );
  }
}

// 内容部分
class _ContentSection extends StatelessWidget {
  final Server server;
  final ServerStatus status;
  final void Function(String, String) onCopy;

  const _ContentSection({
    required this.server,
    required this.status,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusOverviewCard(status: status),
        const SizedBox(height: _DetailConstants.sectionSpacing),
        _BasicInfoCard(status: status, onCopy: onCopy),
        if (status.players != null) ...[
          const SizedBox(height: _DetailConstants.sectionSpacing),
          _PlayersCard(players: status.players!, onCopy: onCopy),
        ],
        if (status.motd != null) ...[
          const SizedBox(height: _DetailConstants.sectionSpacing),
          _MotdCard(motd: status.motd!),
          if (status.online) ...[
            const SizedBox(height: _DetailConstants.sectionSpacing),
            ServerHistoryChart(
              serverIp: server.address,
              port: server.port.toString(),
              chartColor: Colors.green[600]!,
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// 状态概览卡片
class _StatusOverviewCard extends StatelessWidget {
  final ServerStatus status;

  const _StatusOverviewCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _DetailConstants.cardBorderRadius,
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_DetailConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '服务器状态',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatusChip(
                    icon: status.online ? Icons.check_circle : Icons.cancel,
                    label: status.online ? '在线' : '离线',
                    color: status.online ? Colors.green : Colors.red,
                  ),
                ),
                if (status.online && status.players != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusChip(
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
}

// 状态芯片
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: _DetailConstants.chipBorderRadius,
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
}

// 基本信息卡片
class _BasicInfoCard extends StatelessWidget {
  final ServerStatus status;
  final void Function(String, String) onCopy;

  const _BasicInfoCard({
    required this.status,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItemData>[];

    if (status.ipAddress != null) {
      items.add(_InfoItemData(
        icon: Icons.location_on,
        label: 'IP 地址',
        value: status.ipAddress!,
        color: Colors.orange,
        copyable: true,
      ));
    }

    if (status.version != null) {
      items.add(_InfoItemData(
        icon: Icons.category,
        label: '服务器版本',
        value: status.version!,
        color: Colors.purple,
        copyable: false,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _DetailConstants.cardBorderRadius,
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_DetailConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '基本信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map(
                  (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoItem(data: item, onCopy: onCopy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 信息项数据类
class _InfoItemData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool copyable;

  _InfoItemData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.copyable,
  });
}

// 信息项组件
class _InfoItem extends StatelessWidget {
  final _InfoItemData data;
  final void Function(String, String) onCopy;

  const _InfoItem({
    required this.data,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.copyable ? () => onCopy(data.value, data.label) : null,
      borderRadius: _DetailConstants.chipBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: data.color.withOpacity(0.05),
          borderRadius: _DetailConstants.chipBorderRadius,
          border: Border.all(color: data.color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(data.icon, color: data.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: data.color,
                    ),
                  ),
                ],
              ),
            ),
            if (data.copyable) Icon(Icons.copy, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// 玩家卡片
class _PlayersCard extends StatelessWidget {
  final Players players;
  final void Function(String, String) onCopy;

  const _PlayersCard({
    required this.players,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _DetailConstants.cardBorderRadius,
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_DetailConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '在线玩家',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    .map((player) => _PlayerChip(player: player, onCopy: onCopy))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '暂无玩家在线',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 玩家芯片
class _PlayerChip extends StatelessWidget {
  final Player player;
  final void Function(String, String) onCopy;

  const _PlayerChip({
    required this.player,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCopy(player.name, '玩家名称'),
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
}

// MOTD 卡片
class _MotdCard extends StatelessWidget {
  final Motd motd;

  const _MotdCard({required this.motd});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _DetailConstants.cardBorderRadius,
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_DetailConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '服务器简介 (MOTD)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: _DetailConstants.chipBorderRadius,
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