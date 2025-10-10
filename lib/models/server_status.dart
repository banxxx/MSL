import '../utils/text_processor.dart';

class ServerStatus {
  final bool online;
  final String? ipAddress;
  final String? version;
  final Players? players;
  final Motd? motd;
  final String? icon;

  ServerStatus({
    required this.online,
    this.ipAddress,
    this.version,
    this.players,
    this.motd,
    this.icon,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    return ServerStatus(
      online: json['online'] ?? false,
      ipAddress: json['ip_address'],
      version: json['version']?['name_clean'],
      players: json['players'] != null ? Players.fromJson(json['players']) : null,
      motd: json['motd'] != null ? Motd.fromJson(json['motd']) : null,
      icon: json['icon'],
    );
  }
}

class Players {
  final int online;
  final int max;
  final List<Player>? list;

  Players({
    required this.online,
    required this.max,
    this.list,
  });

  factory Players.fromJson(Map<String, dynamic> json) {
    return Players(
      online: json['online'] ?? 0,
      max: json['max'] ?? 0,
      list: json['list'] != null
          ? (json['list'] as List).map((e) => Player.fromJson(e)).toList()
          : null,
    );
  }
}

class Player {
  final String uuid;
  final String name;

  Player({
    required this.uuid,
    required this.name,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      uuid: json['uuid'],
      name: json['name_clean'],
    );
  }
}

class Motd {
  final String raw;
  final String clean;
  final String html;
  final String displayText;

  Motd({
    required this.raw,
    required this.clean,
    required this.html,
  }) : displayText = _getBestDisplayText(clean, raw);

  factory Motd.fromJson(Map<String, dynamic> json) {
    return Motd(
      raw: json['raw']?.toString() ?? '',
      clean: json['clean']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
    );
  }

  static String _getBestDisplayText(String clean, String raw) {
    // 优先使用clean字段，如果没有内容则使用raw字段
    final String sourceText;

    if (clean.isNotEmpty && clean != "null") {
      sourceText = clean;
    } else if (raw.isNotEmpty && raw != "null") {
      sourceText = raw;
    } else {
      return '';
    }

    // 使用深度解码处理中文乱码
    final processed = TextProcessor.deepDecode(sourceText);

    return processed;
  }

  /// 调试方法：获取编码信息
  Map<String, dynamic> getDebugInfo() {
    return {
      'raw': TextProcessor.getEncodingInfo(raw),
      'clean': TextProcessor.getEncodingInfo(clean),
      'html': TextProcessor.getEncodingInfo(html),
      'displayText': displayText,
    };
  }
}