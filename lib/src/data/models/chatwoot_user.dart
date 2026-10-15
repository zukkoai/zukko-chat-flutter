import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../local/hive_type_ids.dart';

part 'chatwoot_user.g.dart';

///
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@HiveType(typeId: chatwootUserHiveTypeId)
class ZukkoChatUser extends Equatable {
  ///custom Zukko Chat user identifier
  @JsonKey()
  @HiveField(0)
  final String? identifier;

  ///custom user identifier hash
  @JsonKey(name: "identifier_hash")
  @HiveField(1)
  final String? identifierHash;

  ///name of Zukko Chat user
  @JsonKey()
  @HiveField(2)
  final String? name;

  ///email of Zukko Chat user
  @JsonKey()
  @HiveField(3)
  final String? email;

  ///profile picture url of user
  @JsonKey(name: "avatar_url")
  @HiveField(4)
  final String? avatarUrl;

  ///any other custom attributes to be linked to the user
  @JsonKey(name: "custom_attributes")
  @HiveField(5)
  final dynamic customAttributes;

  ///phone number of user (E.164, e.g. `+998901234567`)
  @JsonKey(name: "phone_number")
  @HiveField(6)
  final String? phoneNumber;

  const ZukkoChatUser({
    this.identifier,
    this.identifierHash,
    this.name,
    this.email,
    this.avatarUrl,
    this.customAttributes,
    this.phoneNumber,
  });

  /// The copy that is written to disk: without the identity hash (a bearer
  /// proof of the user) and the free-form custom attributes.
  ZukkoChatUser toPersistable() => ZukkoChatUser(
    identifier: identifier,
    name: name,
    email: email,
    avatarUrl: avatarUrl,
    phoneNumber: phoneNumber,
  );

  /// No identity data: this ends up in logs and crash reports.
  @override
  String toString() =>
      'ZukkoChatUser(${identifier == null ? 'anonymous' : 'identified'})';

  @override
  List<Object?> get props => [
    identifier,
    identifierHash,
    name,
    email,
    avatarUrl,
    customAttributes,
    phoneNumber,
  ];

  factory ZukkoChatUser.fromJson(Map<String, dynamic> json) =>
      _$ZukkoChatUserFromJson(json);

  Map<String, dynamic> toJson() => _$ZukkoChatUserToJson(this);
}
