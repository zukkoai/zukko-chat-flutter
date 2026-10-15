import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';

part 'chatwoot_event_message_user.g.dart';

/// The sender of a message (agent or contact).
///
/// {@category FlutterClientSdk}
@HiveType(typeId: chatwootEventUserHiveTypeId)
@JsonSerializable(explicitToJson: true)
class ZukkoChatEventMessageUser extends Equatable {
  @JsonKey(name: "avatar_url")
  @HiveField(0)
  final String? avatarUrl;

  @JsonKey(fromJson: intFromJson)
  @HiveField(1)
  final int? id;

  @JsonKey()
  @HiveField(2)
  final String? name;

  @JsonKey()
  @HiveField(3)
  final String? thumbnail;

  const ZukkoChatEventMessageUser({
    this.id,
    this.avatarUrl,
    this.name,
    this.thumbnail,
  });

  factory ZukkoChatEventMessageUser.fromJson(Map<String, dynamic> json) =>
      _$ZukkoChatEventMessageUserFromJson(json);

  Map<String, dynamic> toJson() => _$ZukkoChatEventMessageUserToJson(this);

  @override
  List<Object?> get props => [id, avatarUrl, name, thumbnail];
}
