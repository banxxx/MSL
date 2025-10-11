import 'dart:async';

import 'package:flutter/material.dart';
import 'package:minecraft_server_link/models/server.dart';
import 'package:minecraft_server_link/services/mcstatus_service.dart';
import 'package:minecraft_server_link/services/settings_notifier.dart';
import 'package:minecraft_server_link/widgets/server_card.dart';
import 'package:minecraft_server_link/widgets/server_dialog.dart';
import 'package:minecraft_server_link/widgets/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
        ProxyProvider<SettingsNotifier, MCStatusService>(
          create: (context) => MCStatusService(
            Provider.of<SettingsNotifier>(context, listen: false),
          ),
          update: (_, settings, previous) =>
          previous ?? MCStatusService(settings),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const ServerListScreen(),
    );
  }
}

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<Server> _servers = [];
  static const _prefsKey = 'saved_servers';
  bool _isLoading = true;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  final Map<String, GlobalKey<ServerCardState>> _serverCardKeys = {};
  final Map<String, bool> _expandedStates = {};

  // 自动刷新相关
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = false;
  int _refreshInterval = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _loadServers();
    _loadAutoRefreshSettings();
  }

  void _initAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopAutoRefresh();
    } else if (state == AppLifecycleState.resumed) {
      _loadAutoRefreshSettings();
    }
  }

  // 加载自动刷新设置
  Future<void> _loadAutoRefreshSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final autoRefresh = prefs.getBool('auto_refresh') ?? false;
    final interval = prefs.getInt('refresh_interval') ?? 30;

    if (mounted) {
      setState(() {
        _autoRefreshEnabled = autoRefresh;
        _refreshInterval = interval;
      });

      if (_autoRefreshEnabled) {
        _startAutoRefresh();
      } else {
        _stopAutoRefresh();
      }
    }
  }

  // 启动自动刷新
  void _startAutoRefresh() {
    _stopAutoRefresh();

    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: _refreshInterval),
          (timer) {
        if (mounted && _servers.isNotEmpty) {
          _silentRefreshAll();
        }
      },
    );
  }

  // 停止自动刷新
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  // 静默刷新所有服务器（不显示加载动画）
  void _silentRefreshAll() {
    for (var key in _serverCardKeys.values) {
      key.currentState?.refreshStatus(showLoading: false);
    }
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedServers = prefs.getStringList(_prefsKey);

    if (savedServers != null) {
      final servers = savedServers
          .map((json) => Server.fromJson(jsonDecode(json)))
          .toList();

      if (mounted) {
        setState(() {
          _servers.addAll(servers);
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _servers.map((server) => jsonEncode(server.toJson())).toList(),
    );
  }

  Future<void> _addServer(Server server) async {
    setState(() {
      _servers.add(server);
    });
    await _saveServers();

    // 同步到后端 API
    final mcStatusService =
    Provider.of<MCStatusService>(context, listen: false);
    final apiSuccess = await mcStatusService.addServer(server);

    if (mounted) {
      _showSnackBar(
        message: apiSuccess
            ? '已添加 ${server.name}'
            : '已添加 ${server.name}（后端同步失败）',
        icon: apiSuccess ? Icons.check_circle : Icons.warning,
        backgroundColor: apiSuccess ? Colors.green[600] : Colors.orange[600],
      );
    }
  }

  Future<void> _editServer(Server oldServer) async {
    final updatedServer = await showDialog<Server>(
      context: context,
      builder: (context) => ServerDialog(server: oldServer),
    );

    if (updatedServer != null) {
      setState(() {
        final index = _servers.indexWhere((s) => s.id == oldServer.id);
        if (index != -1) {
          _servers[index] = updatedServer;
        }
      });
      await _saveServers();

      // 同步到后端 API
      final mcStatusService =
      Provider.of<MCStatusService>(context, listen: false);
      final apiSuccess = await mcStatusService.updateServer(
        updatedServer,
        oldServer.address,
      );

      // 刷新卡片状态
      _serverCardKeys[updatedServer.id]?.currentState?.refreshStatus(
        showLoading: true,
      );

      if (mounted) {
        _showSnackBar(
          message: apiSuccess
              ? '已更新 ${updatedServer.name}'
              : '已更新 ${updatedServer.name}（后端同步失败）',
          icon: apiSuccess ? Icons.check_circle : Icons.warning,
          backgroundColor: apiSuccess ? Colors.blue[600] : Colors.orange[600],
        );
      }
    }
  }

  Future<void> _removeServer(String id) async {
    final server = _servers.firstWhere((s) => s.id == id);
    final index = _servers.indexOf(server);

    setState(() {
      _servers.removeWhere((server) => server.id == id);
    });
    await _saveServers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete, color: Colors.white),
              const SizedBox(width: 12),
              Text('已删除 ${server.name}'),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _servers.insert(index, server);
              });
              _saveServers();
            },
          ),
        ),
      );
    }
  }

  // SnackBar 显示逻辑
  void _showSnackBar({
    required String message,
    required IconData icon,
    required Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showAddServerDialog() async {
    _fabAnimationController.forward().then((_) {
      _fabAnimationController.reverse();
    });

    final server = await showDialog<Server>(
      context: context,
      builder: (context) => const ServerDialog(),
    );

    if (server != null) {
      await _addServer(server);
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _loadAutoRefreshSettings();
  }

  // 下拉刷新处理函数
  Future<void> _handleRefresh() async {
    for (var key in _serverCardKeys.values) {
      key.currentState?.refreshStatus(showLoading: true);
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
        ],
        body: _buildBody(),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _showAddServerDialog,
          icon: const Icon(Icons.add),
          label: const Text(
            '添加服务器',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_servers.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.green[600],
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _servers.length,
        itemBuilder: (context, index) => _buildServerItem(index),
      ),
    );
  }

  Widget _buildServerItem(int index) {
    final server = _servers[index];
    final cardKey = _serverCardKeys.putIfAbsent(
      server.id,
          () => GlobalKey<ServerCardState>(),
    );
    final isExpanded = _expandedStates[server.id] ?? false;

    return Dismissible(
      key: Key(server.id),
      direction: isExpanded ? DismissDirection.none : DismissDirection.horizontal,
      background: _DismissibleBackground.refresh(),
      secondaryBackground: _DismissibleBackground.delete(),
      confirmDismiss: (direction) => _handleDismiss(direction, server, cardKey),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _removeServer(server.id);
        }
      },
      child: ServerCard(
        key: cardKey,
        server: server,
        onDelete: () => _removeServer(server.id),
        onEdit: _editServer,
        onExpandedChanged: (expanded) {
          setState(() {
            _expandedStates[server.id] = expanded;
          });
        },
      ),
    );
  }

  Future<bool?> _handleDismiss(
      DismissDirection direction,
      Server server,
      GlobalKey<ServerCardState> cardKey,
      ) async {
    if (direction == DismissDirection.startToEnd) {
      cardKey.currentState?.refreshStatus(showLoading: true);
      return false;
    } else {
      return await showDialog<bool>(
        context: context,
        builder: (context) => _DeleteConfirmDialog(serverName: server.name),
      );
    }
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.green[600],
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: _navigateToSettings,
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: const _AppBarFlexibleSpace(),
    );
  }
}

// 空状态组件
class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.dns, size: 80, color: Colors.green[300]),
            ),
            const SizedBox(height: 32),
            Text(
              '暂无服务器',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '点击下方按钮添加你的第一个\nMinecraft 服务器',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// AppBar FlexibleSpace
class _AppBarFlexibleSpace extends StatelessWidget {
  const _AppBarFlexibleSpace();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double top = constraints.biggest.height;
        final double collapsedHeight =
            kToolbarHeight + MediaQuery.of(context).padding.top;

        final double opacity =
        ((top - collapsedHeight) / (140 - collapsedHeight)).clamp(0.0, 1.0);

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
                  child: Icon(Icons.dns, size: 200, color: Colors.white),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Opacity(
                  opacity: opacity,
                  child: const Text(
                    'Minecraft 服务器',
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
    );
  }
}

// Dismissible 背景组件
class _DismissibleBackground extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final Color color;
  final IconData icon;

  const _DismissibleBackground({
    required this.alignment,
    required this.padding,
    required this.color,
    required this.icon,
  });

  factory _DismissibleBackground.refresh() {
    return _DismissibleBackground(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      color: Colors.blue[400]!,
      icon: Icons.refresh,
    );
  }

  factory _DismissibleBackground.delete() {
    return _DismissibleBackground(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: Colors.red[400]!,
      icon: Icons.delete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

// 删除确认对话框
class _DeleteConfirmDialog extends StatelessWidget {
  final String serverName;

  const _DeleteConfirmDialog({required this.serverName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          SizedBox(width: 12),
          Text('确认删除'),
        ],
      ),
      content: Text(
        '确定要删除服务器 "$serverName" 吗?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('删除'),
        ),
      ],
    );
  }
}