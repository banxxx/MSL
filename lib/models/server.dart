import 'package:uuid/uuid.dart';

enum ServerType {
  java,
  bedrock;

  String get displayName {
    switch (this) {
      case ServerType.java:
        return 'Java 版';
      case ServerType.bedrock:
        return '基岩版';
    }
  }

  int get defaultPort {
    switch (this) {
      case ServerType.java:
        return 25565;
      case ServerType.bedrock:
        return 19132;
    }
  }
}

class Server {
  final String id;
  final String name;
  final String address;
  final int port;
  final ServerType type;

  Server({
    required this.id,
    required this.name,
    required this.address,
    this.port = 25565,
    this.type = ServerType.java,
  });

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      port: json['port'] ?? 25565,
      type: ServerType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => ServerType.java,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'type': type.name,
    };
  }

  Server copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    ServerType? type,
  }) {
    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      type: type ?? this.type,
    );
  }
}