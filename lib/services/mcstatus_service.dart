import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/history_data_point.dart';
import '../models/server_status.dart';
import '../models/server.dart';

class MCStatusService {
  static const String _baseUrl = 'https://api.mcstatus.io/v2/status/';
  static const String _historyUrl = 'https://minetrack.banxx.cn/api';
  // static const String _historyUrl = 'http://10.0.2.2:8089/api';

  /// 根据服务器类型获取状态
  Future<ServerStatus> getServerStatus(
      String address,
      ServerType type, {
        int? port,
      }) async {
    final endpoint = type == ServerType.java ? 'java' : 'bedrock';
    final fullAddress = port != null ? '$address:$port' : address;

    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint/$fullAddress'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return ServerStatus.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load server status: ${response.statusCode}');
    }
  }

  /// 便捷方法：直接传入 Server 对象
  Future<ServerStatus> getServerStatusFromServer(Server server) async {
    return getServerStatus(
      server.address,
      server.type,
      port: server.port,
    );
  }

  /// 获取历史数据
  Future<HistoryData> getServerHistory(
      String serverIp, String port, {
        int? startTime,
        int? endTime,
        int limit = 1000,
      }) async {
    try {
      // 构建查询参数
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (startTime != null) {
        queryParams['start'] = startTime.toString();
      }
      if (endTime != null) {
        queryParams['end'] = endTime.toString();
      }

      final uri = Uri.parse('$_historyUrl/history/$serverIp/$port')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return HistoryData.fromJson(json);
      } else {
        throw Exception('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching history: $e');
    }
  }

  /// 添加新服务器到后端
  Future<bool> addServer(Server server) async {
    try {
      final uri = Uri.parse('$_historyUrl/servers/add');

      final requestBody = {
        'name': server.name,
        'ip': server.address,
        'port': server.port,
        'type': _convertServerTypeToAPI(server.type),
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return true;
        }
      } else if (response.statusCode == 409) {
        // 服务器已存在，可以视为成功
        return true;
      }

      return false;
    } catch (e) {
      // 不抛出异常，避免影响本地添加
      return false;
    }
  }

  /// 更新服务器信息
  Future<bool> updateServer(Server server, String oldAddress) async {
    try {
      // 使用旧地址作为查询参数，因为 IP 可能被修改了
      final uri = Uri.parse('$_historyUrl/servers/$oldAddress');

      final requestBody = {
        'name': server.name,
        'port': server.port,
        'type': _convertServerTypeToAPI(server.type),
      };


      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return true;
        }
      } else if (response.statusCode == 404) {
        // 服务器不存在于后端，尝试添加
        return await addServer(server);
      }

      return false;
    } catch (e) {
      // 不抛出异常，避免影响本地更新
      return false;
    }
  }

  /// 将 ServerType 转换为 API 期望的格式
  String _convertServerTypeToAPI(ServerType type) {
    return type == ServerType.java ? 'JE' : 'BE';
  }

  /// 从后端删除服务器
  Future<bool> deleteServer(String serverAddress) async {
    try {
      final uri = Uri.parse('$_historyUrl/servers/$serverAddress');

      final response = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}