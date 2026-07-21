import 'package:equatable/equatable.dart';

/// Locally persisted information about a previously paired Bluetooth device.
final class PairedDevice extends Equatable {
  const PairedDevice({
    required this.id,
    required this.name,
    this.lastConnectedAt,
  });

  final String id;
  final String name;
  final DateTime? lastConnectedAt;

  PairedDevice copyWith({String? id, String? name, DateTime? lastConnectedAt}) {
    return PairedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  factory PairedDevice.fromJson(Map<String, Object?> json) {
    final lastConnectedRaw = json['lastConnectedAt'];
    return PairedDevice(
      id: json['id']! as String,
      name: json['name']! as String,
      lastConnectedAt: lastConnectedRaw is String
          ? DateTime.parse(lastConnectedRaw)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, lastConnectedAt];
}
