import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/mcstatus_service.dart';
import '../services/settings_notifier.dart';
import '../widgets/settings_screen.dart';

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

    if (timestamp == null || playerCount == null) {
      throw Exception('HistoryDataPoint: missing required fields');
    }

    return HistoryDataPoint(
      timestamp: timestamp is int ? timestamp : (timestamp as num).toInt(),
      playerCount: playerCount is int ? playerCount : (playerCount as num).toInt(),
    );
  }

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

  static const Map<String, int> _timeRanges = {
    '1h': 1,
    '6h': 6,
    '24h': 24,
    '7d': 168,
    '30d': 720,
  };

  @override
  void initState() {
    super.initState();
    _historyFuture = Future.error('初始化中...');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  void _onTimeRangeChanged(String range) {
    setState(() {
      _selectedTimeRange = range;
      _historyFuture = _fetchHistoryData();
    });
  }

  void _toggleChartType() {
    setState(() {
      _showArea = !_showArea;
    });
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
            _ChartHeader(
              chartColor: widget.chartColor,
              showArea: _showArea,
              onToggleType: _toggleChartType,
              onRefresh: _loadHistory,
            ),
            const SizedBox(height: 20),
            _TimeRangeSelector(
              selectedRange: _selectedTimeRange,
              ranges: _timeRanges.keys.toList(),
              chartColor: widget.chartColor,
              onRangeChanged: _onTimeRangeChanged,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: FutureBuilder<HistoryData>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _ChartLoadingState(chartColor: widget.chartColor);
                  }

                  if (snapshot.hasError) {
                    return _ChartErrorState(
                      error: snapshot.error.toString(),
                      onRetry: _loadHistory,
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.data.isEmpty) {
                    return const _ChartEmptyState();
                  }

                  return _ChartContent(
                    history: snapshot.data!,
                    chartColor: widget.chartColor,
                    showArea: _showArea,
                    timeRange: _selectedTimeRange,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final Color chartColor;
  final bool showArea;
  final VoidCallback onToggleType;
  final VoidCallback onRefresh;

  const _ChartHeader({
    required this.chartColor,
    required this.showArea,
    required this.onToggleType,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.show_chart, color: chartColor, size: 24),
        const SizedBox(width: 12),
        const Text(
          '历史在线人数',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(showArea ? Icons.area_chart : Icons.show_chart, size: 20),
          onPressed: onToggleType,
          tooltip: showArea ? '切换为折线图' : '切换为面积图',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          tooltip: '刷新',
        ),
      ],
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final String selectedRange;
  final List<String> ranges;
  final Color chartColor;
  final ValueChanged<String> onRangeChanged;

  const _TimeRangeSelector({
    required this.selectedRange,
    required this.ranges,
    required this.chartColor,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((range) {
          final isSelected = range == selectedRange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TimeRangeChip(
              label: range,
              isSelected: isSelected,
              color: chartColor,
              onTap: () => onRangeChanged(range),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimeRangeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TimeRangeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? color : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

class _ChartLoadingState extends StatelessWidget {
  final Color chartColor;

  const _ChartLoadingState({required this.chartColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(chartColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加载历史数据...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ChartErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ChartErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isNotConfigured = error.contains('未配置') || error.contains('Minetrack地址未配置');
    final isTimeout = error.contains('连接超时') || error.contains('TimeoutException');

    if (isNotConfigured) {
      return _buildNotConfiguredState(context);
    }

    if (isTimeout) {
      return _buildTimeoutState(context);
    }

    return _buildGenericErrorState(context);
  }

  Widget _buildNotConfiguredState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Minetrack地址未配置',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '请在设置中配置 API 地址',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 60, color: Colors.grey[300]),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
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

  Widget _buildGenericErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '暂无历史数据',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ChartContent extends StatelessWidget {
  final HistoryData history;
  final Color chartColor;
  final bool showArea;
  final String timeRange;

  const _ChartContent({
    required this.history,
    required this.chartColor,
    required this.showArea,
    required this.timeRange,
  });

  @override
  Widget build(BuildContext context) {
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

    final chartConfig = _ChartConfiguration(
      sortedData: sortedData,
      timeRange: timeRange,
    );

    return LineChart(
      LineChartData(
        gridData: _buildGridData(),
        titlesData: _buildTitlesData(sortedData, chartConfig),
        borderData: _buildBorderData(),
        minX: 0,
        maxX: spots.length > 1 ? spots.length.toDouble() - 1 : 1,
        minY: chartConfig.minY,
        maxY: chartConfig.maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: chartColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: showArea,
              gradient: LinearGradient(
                colors: [
                  chartColor.withOpacity(0.3),
                  chartColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: _buildTouchData(sortedData, chartColor),
      ),
    );
  }

  FlGridData _buildGridData() {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (value) {
        return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
      },
      getDrawingVerticalLine: (value) {
        return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
      },
    );
  }

  FlTitlesData _buildTitlesData(
      List<HistoryDataPoint> sortedData,
      _ChartConfiguration config,
      ) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: config.xInterval,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= sortedData.length) {
              return const SizedBox.shrink();
            }

            if (index % config.xInterval.toInt() != 0) {
              return const SizedBox.shrink();
            }

            final point = sortedData[index];
            final time = config.timeFormat.format(point.dateTime);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                time,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: config.yInterval,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value % 1 != 0) {
              return const SizedBox.shrink();
            }
            return Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            );
          },
        ),
      ),
    );
  }

  FlBorderData _buildBorderData() {
    return FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey[200]!),
    );
  }

  LineTouchData _buildTouchData(
      List<HistoryDataPoint> sortedData,
      Color chartColor,
      ) {
    return LineTouchData(
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
    );
  }
}

class _ChartConfiguration {
  final double minY;
  final double maxY;
  final double yInterval;
  final double xInterval;
  final DateFormat timeFormat;

  _ChartConfiguration({
    required List<HistoryDataPoint> sortedData,
    required String timeRange,
  })  : minY = _calculateMinY(sortedData),
        maxY = _calculateMaxY(sortedData),
        yInterval = _calculateYInterval(sortedData),
        xInterval = _calculateXInterval(sortedData, timeRange),
        timeFormat = _getTimeFormat(timeRange);

  static double _calculateMinY(List<HistoryDataPoint> data) {
    final minValue =
    data.map((e) => e.playerCount).reduce((a, b) => a < b ? a : b).toDouble();
    final maxValue =
    data.map((e) => e.playerCount).reduce((a, b) => a > b ? a : b).toDouble();
    final dataRange = maxValue - minValue;

    if (dataRange == 0) {
      return minValue > 5 ? minValue - 5 : 0;
    } else if (dataRange < 10) {
      return (minValue - 2).clamp(0, double.infinity);
    } else {
      final padding = dataRange * 0.1;
      return (minValue - padding).clamp(0, double.infinity);
    }
  }

  static double _calculateMaxY(List<HistoryDataPoint> data) {
    final minValue =
    data.map((e) => e.playerCount).reduce((a, b) => a < b ? a : b).toDouble();
    final maxValue =
    data.map((e) => e.playerCount).reduce((a, b) => a > b ? a : b).toDouble();
    final dataRange = maxValue - minValue;

    if (dataRange == 0) {
      return minValue + 10;
    } else if (dataRange < 10) {
      return maxValue + 2;
    } else {
      final padding = dataRange * 0.1;
      return maxValue + padding;
    }
  }

  static double _calculateYInterval(List<HistoryDataPoint> data) {
    final minValue =
    data.map((e) => e.playerCount).reduce((a, b) => a < b ? a : b).toDouble();
    final maxValue =
    data.map((e) => e.playerCount).reduce((a, b) => a > b ? a : b).toDouble();
    final dataRange = maxValue - minValue;

    if (dataRange == 0) {
      return 2;
    } else if (dataRange < 10) {
      return 1;
    } else {
      return dataRange / 5;
    }
  }

  static double _calculateXInterval(List<HistoryDataPoint> data, String timeRange) {
    int labelCount;
    switch (timeRange) {
      case '1h':
      case '6h':
        labelCount = 6;
        break;
      case '24h':
        labelCount = 8;
        break;
      case '7d':
        labelCount = 7;
        break;
      case '30d':
        labelCount = 6;
        break;
      default:
        labelCount = 6;
    }

    return data.length > labelCount
        ? (data.length / (labelCount - 1)).floorToDouble()
        : 1.0;
  }

  static DateFormat _getTimeFormat(String timeRange) {
    switch (timeRange) {
      case '1h':
      case '6h':
      case '24h':
        return DateFormat('HH:mm');
      case '7d':
      case '30d':
        return DateFormat('MM-dd');
      default:
        return DateFormat('HH:mm');
    }
  }
}