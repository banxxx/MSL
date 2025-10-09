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
        Provider(create: (_) => MCStatusService()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()),
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
      title: 'Minecraft Server Link',
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
  final _prefsKey = 'saved_servers';
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
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _loadServers();
    _loadAutoRefreshSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh(); // 停止定时器
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用进入后台时停止自动刷新，恢复前台时重新开始
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

    print('🔄 加载自动刷新设置: 启用=$autoRefresh, 间隔=${interval}秒');

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
    _stopAutoRefresh(); // 先停止之前的定时器

    print('✅ 启动自动刷新，间隔: $_refreshInterval 秒');

    _autoRefreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (
      timer,
    ) {
      print('🔄 自动刷新触发 - ${DateTime.now()}');

      if (mounted && _servers.isNotEmpty) {
        _silentRefreshAll();
      }
    });
  }

  // 停止自动刷新
  void _stopAutoRefresh() {
    if (_autoRefreshTimer != null) {
      print('❌ 停止自动刷新'); // 添加日志
    }

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  // 静默刷新所有服务器（不显示加载动画）
  void _silentRefreshAll() {
    print('📡 静默刷新 ${_servers.length} 个服务器');
    for (var key in _serverCardKeys.values) {
      key.currentState?.refreshStatus(showLoading: false);
    }
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedServers = prefs.getStringList(_prefsKey);

    if (savedServers != null) {
      setState(() {
        _servers.addAll(
          savedServers
              .map((json) => Server.fromJson(jsonDecode(json)))
              .toList(),
        );
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _servers.map((server) => jsonEncode(server.toJson())).toList(),
    );
  }

  Future<void> _addServer(Server server) async {
    // 先添加到本地
    setState(() {
      _servers.add(server);
    });
    await _saveServers();

    // 同步到后端 API
    final mcStatusService = Provider.of<MCStatusService>(context, listen: false);
    final apiSuccess = await mcStatusService.addServer(server);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                apiSuccess ? Icons.check_circle : Icons.warning,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                apiSuccess
                    ? '已添加 ${server.name}'
                    : '已添加 ${server.name}（后端同步失败）',
              ),
            ],
          ),
          backgroundColor: apiSuccess ? Colors.green[600] : Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _editServer(Server oldServer) async {
    final updatedServer = await showDialog<Server>(
      context: context,
      builder: (context) => ServerDialog(server: oldServer),
    );

    if (updatedServer != null) {
      // 先更新本地
      setState(() {
        final index = _servers.indexWhere((s) => s.id == oldServer.id);
        if (index != -1) {
          _servers[index] = updatedServer;
        }
      });
      await _saveServers();

      // 同步到后端 API（使用旧地址作为标识）
      final mcStatusService = Provider.of<MCStatusService>(context, listen: false);
      final apiSuccess = await mcStatusService.updateServer(
        updatedServer,
        oldServer.address, // 使用旧地址定位服务器
      );

      // 刷新卡片状态
      _serverCardKeys[updatedServer.id]?.currentState?.refreshStatus(
        showLoading: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  apiSuccess ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  apiSuccess
                      ? '已更新 ${updatedServer.name}'
                      : '已更新 ${updatedServer.name}（后端同步失败）',
                ),
              ],
            ),
            backgroundColor: apiSuccess ? Colors.blue[600] : Colors.orange[600],
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
    // 从设置页面返回时重新加载设置
    _loadAutoRefreshSettings();
  }

  // 下拉刷新处理函数
  Future<void> _handleRefresh() async {
    // 触发所有 ServerCard 刷新
    for (var key in _serverCardKeys.values) {
      key.currentState?.refreshStatus(showLoading: true);
    }

    // 等待一小段时间让刷新动画完成
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildAppBar()],
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _servers.isEmpty
                ? _buildEmptyStateBody()
                : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: Colors.green[600],
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: _servers.length,
                    itemBuilder: (context, index) {
                      final server = _servers[index];
                      final cardKey = _serverCardKeys.putIfAbsent(
                        server.id,
                        () => GlobalKey<ServerCardState>(),
                      );
                      final isExpanded = _expandedStates[server.id] ?? false;

                      return Dismissible(
                        key: Key(server.id),
                        direction:
                            isExpanded
                                ? DismissDirection
                                    .none // 展开时禁用滑动
                                : DismissDirection.horizontal,
                        // 收起时允许滑动
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            cardKey.currentState?.refreshStatus(showLoading: true);
                            return false;
                          } else {
                            return await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
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
                                      '确定要删除服务器 "${server.name}" 吗?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[600],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        },
                        onDismissed: (direction) {
                          if (direction == DismissDirection.endToStart) {
                            _removeServer(server.id);
                          }
                        },
                        child: ServerCard(
                          key: cardKey,
                          server: server,
                          onDelete: () => _removeServer(server.id),
                          // 编辑回调
                          onEdit: _editServer,
                          // 添加展开状态变化的回调
                          onExpandedChanged: (expanded) {
                            setState(() {
                              _expandedStates[server.id] = expanded;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
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

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.green[600],
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: _navigateToSettings,
          tooltip: '设置',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Minecraft 服务器',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black54,
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
                  child: Icon(Icons.dns, size: 200, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateBody() {
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
