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

  const ServerCard({
    super.key,
    required this.server,
    required this.onDelete,
    this.onExpandedChanged,
    this.onEdit,
  });

  @override
  State<ServerCard> createState() => ServerCardState();
}

class ServerCardState extends State<ServerCard>
    with SingleTickerProviderStateMixin {
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
    _isLoading = true;
    _initAnimations();
    refreshStatus(showLoading: true);
  }

  void _initAnimations() {
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

  void refreshStatus({bool showLoading = true}) {
    final service = context.read<MCStatusService>();

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _cachedStatus = null;
        _cachedError = null;
        _statusFuture = service.getServerStatusFromServer(widget.server);
      });
    } else {
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
            _cachedStatus = null;
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

  @override
  Widget build(BuildContext context) {
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
                  child: _buildContent(settings),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(SettingsNotifier settings) {
    if (_cachedStatus != null) {
      return _buildSuccessContent(_cachedStatus!, settings);
    }

    if (_cachedError != null) {
      return _buildErrorState(settings);
    }

    return FutureBuilder<ServerStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(settings);
        }

        if (snapshot.hasError) {
          return _buildErrorState(settings);
        }

        final status = snapshot.data!;
        _cachedStatus = status;
        _cachedError = null;
        _isLoading = false;

        return _buildSuccessContent(status, settings);
      },
    );
  }

  Widget _buildSuccessContent(ServerStatus status, SettingsNotifier settings) {
    return Column(
      children: [
        _ServerCardHeader(
          server: widget.server,
          status: status,
          settings: settings,
          isExpanded: _isExpanded,
          rotationAnimation: _rotationAnimation,
          onIconTap: () => _navigateToDetail(status, settings),
        ),
        if (_isExpanded)
          _ServerCardExpandedContent(
            status: status,
            settings: settings,
          ),
      ],
    );
  }

  Widget _buildLoadingState(SettingsNotifier settings) {
    return _ServerCardLoadingState(
      server: widget.server,
      settings: settings,
    );
  }

  Widget _buildErrorState(SettingsNotifier settings) {
    return _ServerCardErrorState(
      server: widget.server,
      settings: settings,
    );
  }

  void _navigateToDetail(ServerStatus status, SettingsNotifier settings) {
    if (settings.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServerDetailScreen(
          server: widget.server,
          initialStatus: _cachedStatus,
        ),
      ),
    );
  }
}

class _ServerCardHeader extends StatelessWidget {
  final Server server;
  final ServerStatus status;
  final SettingsNotifier settings;
  final bool isExpanded;
  final Animation<double> rotationAnimation;
  final VoidCallback onIconTap;

  const _ServerCardHeader({
    required this.server,
    required this.status,
    required this.settings,
    required this.isExpanded,
    required this.rotationAnimation,
    required this.onIconTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ServerIcon(
          iconData: status.icon,
          onTap: onIconTap,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ServerInfo(
            server: server,
            status: status,
            settings: settings,
          ),
        ),
        const SizedBox(width: 8),
        RotationTransition(
          turns: rotationAnimation,
          child: Icon(Icons.expand_more, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _ServerIcon extends StatelessWidget {
  final String? iconData;
  final VoidCallback onTap;

  const _ServerIcon({
    required this.iconData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 65.0;

    Widget iconWidget;

    if (iconData == null || iconData!.isEmpty) {
      iconWidget = _buildFallbackIcon(size);
    } else {
      try {
        final bytes = base64Decode(iconData!.split(',').last);
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
      child: Icon(Icons.dns, size: size * 0.5, color: Colors.white),
    );
  }
}

class _ServerInfo extends StatelessWidget {
  final Server server;
  final ServerStatus status;
  final SettingsNotifier settings;

  const _ServerInfo({
    required this.server,
    required this.status,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          server.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _BlurredIpAddress(
          address: server.address,
          blurred: settings.blurIpAddress,
        ),
        const SizedBox(height: 8),
        _StatusBadge(status: status, settings: settings),
      ],
    );
  }
}

class _BlurredIpAddress extends StatelessWidget {
  final String address;
  final bool blurred;

  const _BlurredIpAddress({
    required this.address,
    required this.blurred,
  });

  @override
  Widget build(BuildContext context) {
    if (!blurred) {
      return Text(
        address,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    const edgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          Padding(
            padding: edgePadding,
            child: Text(
              address,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: edgePadding,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ServerStatus status;
  final SettingsNotifier settings;

  const _StatusBadge({
    required this.status,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (!status.online) {
      return _Badge(
        icon: Icons.cancel,
        label: '离线',
        color: Colors.red,
      );
    }

    final players = status.players;
    if (players == null || !settings.showPlayerCount) {
      return _Badge(
        icon: Icons.check_circle,
        label: '在线',
        color: Colors.green,
      );
    }

    return Row(
      children: [
        _Badge(
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
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _ServerCardExpandedContent extends StatelessWidget {
  final ServerStatus status;
  final SettingsNotifier settings;

  const _ServerCardExpandedContent({
    required this.status,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(height: 1, color: Colors.grey[200]),
        const SizedBox(height: 16),
        if (status.version != null)
          _InfoCard(
            icon: Icons.category,
            title: '版本',
            content: status.version!,
            color: Colors.purple,
          ),
        if (settings.showPlayerCount && status.players?.list != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _PlayersCard(players: status.players!),
          ),
        if (settings.showMotd && status.motd?.displayText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _MotdCard(motd: status.motd!),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _PlayersCard extends StatelessWidget {
  final Players players;

  const _PlayersCard({required this.players});

  @override
  Widget build(BuildContext context) {
    final playerList = players.list ?? [];
    if (playerList.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    int validCount = 0;

    for (final player in playerList) {
      if (player.name.isEmpty) continue;

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

      validCount++;

      if (validCount >= 10 && children.length >= 10) {
        break;
      }
    }

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
}

class _MotdCard extends StatelessWidget {
  final Motd motd;

  const _MotdCard({required this.motd});

  @override
  Widget build(BuildContext context) {
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
}

class _ServerCardLoadingState extends StatelessWidget {
  final Server server;
  final SettingsNotifier settings;

  const _ServerCardLoadingState({
    required this.server,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ServerIcon(
          iconData: null,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                server.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _BlurredIpAddress(
                address: server.address,
                blurred: settings.blurIpAddress,
              ),
              const SizedBox(height: 8),
              _Badge(
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
}

class _ServerCardErrorState extends StatelessWidget {
  final Server server;
  final SettingsNotifier settings;

  const _ServerCardErrorState({
    required this.server,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ServerIcon(
          iconData: null,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                server.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _BlurredIpAddress(
                address: server.address,
                blurred: settings.blurIpAddress,
              ),
              const SizedBox(height: 8),
              _Badge(
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
}