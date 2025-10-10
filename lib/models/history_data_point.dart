import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/mcstatus_service.dart';
import '../services/settings_notifier.dart';
import '../widgets/settings_screen.dart';

// ========== 数据模型 ==========
class HistoryDataPoint {
  final int timestamp;
  final int playerCount;

  HistoryDataPoint({
    required this.timestamp,
    required this.playerCount,
  });

  factory HistoryDataPoint.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    final playerCount = json['playerCount'];

    if (timestamp == null) {
      throw Exception('HistoryDataPoint: timestamp is null');
    }
    if (playerCount == null) {
      throw Exception('HistoryDataPoint: playerCount is null');
    }

    return HistoryDataPoint(
      timestamp: timestamp is int ? timestamp : (timestamp as num).toInt(),
      playerCount: playerCount is int ? playerCount : (playerCount as num).toInt(),
    );
  }

  // 使用本地时区
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
}

class HistoryData {
  final String ip;
  final String port;
  final List<HistoryDataPoint> data;

  HistoryData({
    required this.ip,
    required this.port,
    required this.data,
  });

  factory HistoryData.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'];

    if (dataList == null) {
      return HistoryData(
        ip: json['ip'] as String? ?? '',
        port: json['port'] as String? ?? '25565',
        data: [],
      );
    }

    final List<HistoryDataPoint> points = [];
    for (var item in dataList) {
      try {
        points.add(HistoryDataPoint.fromJson(item));
      } catch (e) {
        continue;
      }
    }

    return HistoryData(
      ip: json['ip'] as String? ?? '',
      port: json['port'] as String? ?? '25565',
      data: points,
    );
  }
}

// ========== 图表组件 ==========
class ServerHistoryChart extends StatefulWidget {
  final String serverIp;
  final String port;
  final Color chartColor;

  const ServerHistoryChart({
    super.key,
    required this.serverIp,
    required this.port,
    this.chartColor = Colors.green,
  });

  @override
  State<ServerHistoryChart> createState() => _ServerHistoryChartState();
}

class _ServerHistoryChartState extends State<ServerHistoryChart> {
  late Future<HistoryData> _historyFuture;
  String _selectedTimeRange = '24h';
  bool _showArea = true;

  final Map<String, int> _timeRanges = {
    '1h': 1,
    '6h': 6,
    '24h': 24,
    '7d': 168,
    '30d': 720,
  };

  @override
  void initState() {
    super.initState();
    // 初始化为未配置状态
    _historyFuture = Future.error('初始化中...');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在这里可以安全地访问 context
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _fetchHistoryData();
    });
  }

  Future<HistoryData> _fetchHistoryData() async {
    try {
      final settings = context.read<SettingsNotifier>();
      final service = MCStatusService(settings);

      final hours = _timeRanges[_selectedTimeRange]!;
      final endTime = DateTime.now().toUtc().millisecondsSinceEpoch;
      final startTime = endTime - (hours * 60 * 60 * 1000);

      return await service.getServerHistory(
        widget.serverIp,
        widget.port,
        startTime: startTime,
        endTime: endTime,
        limit: 100000,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _buildHeader(),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: FutureBuilder<HistoryData>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    final errorMsg = snapshot.error.toString();
                    // 检查是否是未配置错误
                    if (errorMsg.contains('未配置') ||
                        errorMsg.contains('Minetrack地址未配置')) {
                      return _buildEmptyState(isNotConfigured: true);
                    }

                    if (errorMsg.contains('连接超时') || errorMsg.contains('TimeoutException')) {
                      return _buildTimeoutState();
                    }

                    return _buildErrorState(errorMsg);
                  }

                  if (!snapshot.hasData || snapshot.data!.data.isEmpty) {
                    return _buildEmptyState(isNotConfigured: false);
                  }

                  return _buildChart(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '连接超时',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '无法连接到 Minetrack 服务器\n请检查网络或服务器配置',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('设置'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: widget.chartColor, size: 24),
            const SizedBox(width: 12),
            const Text(
              '历史在线人数',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                _showArea ? Icons.area_chart : Icons.show_chart,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _showArea = !_showArea;
                });
              },
              tooltip: _showArea ? '切换为折线图' : '切换为面积图',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadHistory,
              tooltip: '刷新',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTimeRangeSelector(),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _timeRanges.keys.map((range) {
          final isSelected = range == _selectedTimeRange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                // 直接在 setState 中调用（推荐）
                setState(() {
                  _selectedTimeRange = range;
                  _historyFuture = _fetchHistoryData();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.chartColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? widget.chartColor
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  range,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? widget.chartColor
                        : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(HistoryData history) {
    if (history.data.isEmpty) {
      return _buildEmptyState(isNotConfigured: false);
    }

    final sortedData = List<HistoryDataPoint>.from(history.data)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = sortedData
        .asMap()
        .entries
        .map((entry) => FlSpot(
      entry.key.toDouble(),
      entry.value.playerCount.toDouble(),
    ))
        .toList();

    final maxY = sortedData
        .map((e) => e.playerCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final minY = sortedData
        .map((e) => e.playerCount)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();

    final dataRange = maxY - minY;
    double yInterval;
    double actualMinY;
    double actualMaxY;

    if (dataRange == 0) {
      actualMinY = minY > 5 ? minY - 5 : 0;
      actualMaxY = minY + 10;
      yInterval = 2;
    } else if (dataRange < 10) {
      actualMinY = (minY - 2).clamp(0, double.infinity);
      actualMaxY = maxY + 2;
      yInterval = 1;
    } else {
      final padding = dataRange * 0.1;
      actualMinY = (minY - padding).clamp(0, double.infinity);
      actualMaxY = maxY + padding;
      yInterval = dataRange / 5;
    }

    // 根据时间范围选择不同的时间格式和显示数量
    DateFormat timeFormat;
    int labelCount;

    switch (_selectedTimeRange) {
      case '1h':
        timeFormat = DateFormat('HH:mm');
        labelCount = 6;
        break;
      case '6h':
        timeFormat = DateFormat('HH:mm');
        labelCount = 6;
        break;
      case '24h':
        timeFormat = DateFormat('HH:mm');
        labelCount = 8;
        break;
      case '7d':
        timeFormat = DateFormat('MM-dd');
        labelCount = 7;
        break;
      case '30d':
        timeFormat = DateFormat('MM-dd');
        labelCount = 6;
        break;
      default:
        timeFormat = DateFormat('HH:mm');
        labelCount = 6;
    }

    // 计算X轴标签间隔
    final xInterval = spots.length > labelCount
        ? (spots.length / (labelCount - 1)).floorToDouble()
        : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedData.length) {
                  return const SizedBox.shrink();
                }

                if (index % xInterval.toInt() != 0) {
                  return const SizedBox.shrink();
                }

                final point = sortedData[index];
                final time = timeFormat.format(point.dateTime);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[200]!),
        ),
        minX: 0,
        maxX: spots.length > 1 ? spots.length.toDouble() - 1 : 1,
        minY: actualMinY,
        maxY: actualMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: widget.chartColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: _showArea,
              gradient: LinearGradient(
                colors: [
                  widget.chartColor.withOpacity(0.3),
                  widget.chartColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= sortedData.length) {
                  return null;
                }
                final point = sortedData[index];
                final time = DateFormat('yyyy-MM-dd HH:mm').format(point.dateTime);
                return LineTooltipItem(
                  '$time\n${spot.y.toInt()} 玩家',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchLineStart: (data, index) => 0,
          getTouchLineEnd: (data, index) => 0,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(widget.chartColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加载历史数据...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isNotConfigured}) {
    final settings = context.read<SettingsNotifier>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNotConfigured ? Icons.show_chart : Icons.search_off,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isNotConfigured ? 'Minetrack地址未配置' : '暂无历史数据',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNotConfigured
                ? '请在设置中配置 API 地址'
                : '时间范围: $_selectedTimeRange',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          if (isNotConfigured) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
              icon: const Icon(Icons.settings),
              label: const Text('前往设置'),
            ),
          ],
        ],
      ),
    );
  }
}