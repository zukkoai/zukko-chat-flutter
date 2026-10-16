import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../local/hive_type_ids.dart';
import 'zukko_chat_attachment.dart' show jsonMapFromJson;

part 'zukko_chat_user.g.dart';

/// The visitor's identity, passed to `ZukkoChatClient.create`. Never written to
/// disk: Hive type id 3 stays reserved for this class (an adapter is still
/// registered so old records stay readable by other tools), but the SDK stores
/// no user.
///
/// {@category FlutterClientSdk}
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@HiveType(typeId: zukkoChatUserHiveTypeId)
class ZukkoChatUser extends Equatable {
  ///custom Zukko Chat user identifier
  @HiveField(0)
  final String? identifier;

  ///custom user identifier hash
  @JsonKey(name: "identifier_hash")
  @HiveField(1)
  final String? identifierHash;

  ///name of Zukko Chat user
  @HiveField(2)
  final String? name;

  ///email of Zukko Chat user
  @HiveField(3)
  final String? email;

  ///profile picture url of user
  @JsonKey(name: "avatar_url")
  @HiveField(4)
  final String? avatarUrl;

  ///any other custom attributes to be linked to the user
  @JsonKey(name: "custom_attributes", fromJson: jsonMapFromJson)
  @HiveField(5)
  final Map<String, dynamic>? customAttributes;

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
