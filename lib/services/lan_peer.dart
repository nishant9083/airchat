class LanPeer {
  final String userId;
  final String name;
  final String ip;
  final int port;

  LanPeer({
    required this.userId,
    required this.name,
    required this.ip,
    required this.port,
  });

  factory LanPeer.fromJson(Map<String, dynamic> json) {
    return LanPeer(
      userId: json['userId'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'ip': ip,
        'port': port,
      };

  @override
  String toString() => 'LanPeer(userId: $userId, name: $name, ip: $ip, port: $port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanPeer &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => userId.hashCode ^ ip.hashCode ^ port.hashCode;
} 