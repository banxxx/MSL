import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:minecraft_server_link/models/server.dart';
import 'package:minecraft_server_link/models/server_status.dart';
import 'package:minecraft_server_link/services/mcstatus_service.dart';
import 'package:minecraft_server_link/services/settings_notifier.dart';
import 'package:minecraft_server_link/widgets/server_detail_screen.dart';
import 'package:provider/provider.dart';

class ServerCard extends StatefulWidget {
  final Server server;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onExpandedChanged;
  final ValueChanged<Server>? onEdit;

  const ServerCard({super.key, required this.server, required this.onDelete, this.onExpandedChanged, this.onEdit,});

  @override
  State<ServerCard> createState() => ServerCardState();
}

class ServerCardState extends State<ServerCard> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Future<ServerStatus> _statusFuture;
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  // 用于静默刷新的状态
  bool _isLoading = true;
  ServerStatus? _cachedStatus;
  String? _cachedError;

  @override
  void initState() {
    super.initState();
    // 初始化时显示加载状态
    _isLoading = true;
    refreshStatus(showLoading: true);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // refreshStatus 方法，支持 showLoading 参数
  void refreshStatus({bool showLoading = true}) {
    final service = context.read<MCStatusService>();

    if (showLoading) {
      // 显示加载状态：清空缓存，显示加载动画
      setState(() {
        _isLoading = true;
        _cachedStatus = null;  // 清空缓存
        _cachedError = null;   // 清空错误
        _statusFuture = service.getServerStatusFromServer(widget.server);
      });
    } else {
      // 静默刷新：在后台更新，保留现有显示
      service.getServerStatusFromServer(widget.server).then((status) {
        if (mounted) {
          setState(() {
            _cachedStatus = status;
            _cachedError = null;
            _isLoading = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _cachedError = error.toString();
            _cachedStatus = null; // 清空缓存
            _isLoading = false;
          });
        }
      });
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onExpandedChanged?.call(_isExpanded);
  }

  void _handleLongPress(SettingsNotifier settings) {
    if (settings.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    widget.onEdit?.call(widget.server);
  }

  Widget _buildIpAddress(String address, bool blurIpAddress) {
    if (!blurIpAddress) {
      return Text(
        address,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 统一定义padding值
    const edgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          // 底层文字（添加padding）
          Padding(
            padding: edgePadding,
            child: Text(
              address,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 毛玻璃模糊层
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: edgePadding, // 使用相同的padding
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsNotifier>(
      builder: (context, settings, child) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleExpanded,
                onLongPress: () => _handleLongPress(settings),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(theme, settings),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 统一的内容构建方法
  Widget _buildContent(ThemeData theme, SettingsNotifier settings) {
    // 移除内部的 Consumer，直接使用传入的 settings
    // 如果有缓存数据，直接使用缓存
    if (_cachedStatus != null) {
      return Column(
        children: [
          _buildHeader(_cachedStatus!, theme, settings),
          if (_isExpanded)
            _buildExpandedContent(_cachedStatus!, theme, settings),
        ],
      );
    }

    // 如果有缓存错误，显示错误状态
    if (_cachedError != null) {
      return _buildErrorState(theme, settings);
    }

    // 否则使用 FutureBuilder（初次加载或手动刷新）
    return FutureBuilder<ServerStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(settings);
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, settings);
        }

        final status = snapshot.data!;
        // 更新缓存
        _cachedStatus = status;
        _cachedError = null;
        _isLoading = false;

        return Column(
          children: [
            _buildHeader(status, theme, settings),
            if (_isExpanded)
              _buildExpandedContent(status, theme, settings),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState(SettingsNotifier settings) {
    return Row(
      children: [
        _buildServerIcon(null, settings),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.server.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildIpAddress(widget.server.address, settings.blurIpAddress),
              const SizedBox(height: 8),
              // 加载状态下的状态徽章占位
              _buildBadge(
                icon: Icons.refresh,
                label: '检查中',
                color: Colors.orange,
              ),
            ],
          ),
        ),
        const SpinKitFadingCircle(
          color: Colors.blue,
          size: 24,
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, SettingsNotifier settings) {
    return Row(
      children: [
        _buildServerIcon(null, settings),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.server.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildIpAddress(widget.server.address, settings.blurIpAddress),
              const SizedBox(height: 8),
              _buildBadge(
                icon: Icons.error_outline,
                label: '无法连接',
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ServerStatus status, ThemeData theme, SettingsNotifier settings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildServerIcon(status.icon, settings),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.server.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _buildIpAddress(widget.server.address, settings.blurIpAddress),
              const SizedBox(height: 8),
              _buildStatusBadge(status, settings),
            ],
          ),
        ),
        const SizedBox(width: 8),
        RotationTransition(
          turns: _rotationAnimation,
          child: Icon(
            Icons.expand_more,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ServerStatus status, SettingsNotifier settings) {
    if (!status.online) {
      return _buildBadge(
        icon: Icons.cancel,
        label: '离线',
        color: Colors.red,
      );
    }

    final players = status.players;
    if (players == null || !settings.showPlayerCount) {
      return _buildBadge(
        icon: Icons.check_circle,
        label: '在线',
        color: Colors.green,
      );
    }

    return Row(
      children: [
        _buildBadge(
          icon: Icons.check_circle,
          label: '在线',
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 14, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text(
                '${players.online}/${players.max}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(ServerStatus status, ThemeData theme, SettingsNotifier settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.grey[200]),
        const SizedBox(height: 16),

        // 版本信息
        if (status.version != null)
          _buildInfoCard(
            icon: Icons.category,
            title: '版本',
            content: status.version!,
            color: Colors.purple,
          ),

        // 在线玩家
        if (settings.showPlayerCount && status.players?.list != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildPlayersCard(status.players!, theme),
          ),

        // MOTD
        if (settings.showMotd && status.motd?.displayText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildMotdCard(status.motd!, theme),
          ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard(Players players, ThemeData theme) {
    // 直接处理原始列表，避免创建完整过滤列表
    final playerList = players.list ?? [];

    // 如果没有玩家，不显示卡片
    if (playerList.isEmpty) {
      return const SizedBox.shrink();
    }

    // 只构建最多10个有效玩家标签
    final children = <Widget>[];
    int validCount = 0;

    for (final player in playerList) {
      // 跳过无效玩家
      if (player.name.isEmpty) continue;

      // 只构建前10个有效玩家
      if (validCount < 10) {
        children.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              player.name,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }

      // 计数有效玩家（即使超过10个也继续计数）
      validCount++;

      // 如果已经收集到10个有效玩家，可以提前终止循环
      if (validCount >= 10 && children.length >= 10) {
        break;
      }
    }

    // 如果没有有效玩家，不显示卡片
    if (validCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '在线玩家',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildMotdCard(Motd motd, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 20, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text(
                '服务器简介',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            motd.displayText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.amber[900],
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildServerIcon(String? iconData, SettingsNotifier settings) {
    const size = 65.0;

    Widget iconWidget;

    if (iconData == null || iconData.isEmpty) {
      iconWidget = _buildFallbackIcon(size);
    } else {
      try {
        final bytes = base64Decode(iconData.split(',').last);
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
            errorBuilder: (_, __, ___) => _buildFallbackIcon(size),
          ),
        );
      } catch (e) {
        iconWidget = _buildFallbackIcon(size);
      }
    }

    // 包裹 InkWell 添加点击效果
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 直接使用传入的 settings 参数
          if (settings.hapticFeedback) {
            HapticFeedback.lightImpact();
          }

          // 导航到详情页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServerDetailScreen(
                server: widget.server,
                initialStatus: _cachedStatus,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: iconWidget,
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.dns,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }
}