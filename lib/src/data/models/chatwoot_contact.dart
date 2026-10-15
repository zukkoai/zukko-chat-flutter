import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../local/hive_type_ids.dart';

part 'chatwoot_contact.g.dart';

@JsonSerializable(explicitToJson: true)
@HiveType(typeId: chatwootContactHiveTypeId)
class ChatwootContact extends Equatable {
  ///unique identifier of contact
  @JsonKey(name: "id")
  @HiveField(0)
  final int id;

  ///Identifier of the contact (the `identifier` set through `set_user`;
  ///null for anonymous visitors)
  @JsonKey(name: "identifier")
  @HiveField(1)
  final String? contactIdentifier;

  ///Token for subscribing to websocket stream events
  @JsonKey(name: "pubsub_token")
  @HiveField(2)
  final String? pubsubToken;

  ///Full name of contact
  @JsonKey()
  @HiveField(3)
  final String? name;

  ///Email of contact
  @JsonKey()
  @HiveField(4)
  final String? email;

  ///Phone number of contact
  @JsonKey(name: "phone_number")
  @HiveField(6)
  final String? phoneNumber;

  ///Widget session JWT (`X-Auth-Token`). A bearer secret: kept only in the
  ///encrypted contact box, never serialised to JSON and never printed.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @HiveField(5)
  final String? authToken;

  const ChatwootContact({
    required this.id,
    required this.contactIdentifier,
    required this.pubsubToken,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.authToken,
  });

  /// A copy with the given (non-null) fields replaced.
  ChatwootContact copyWith({
    String? authToken,
    String? contactIdentifier,
    String? name,
    String? email,
    String? phoneNumber,
  }) => ChatwootContact(
    id: id,
    contactIdentifier: contactIdentifier ?? this.contactIdentifier,
    pubsubToken: pubsubToken,
    name: name ?? this.name,
    email: email ?? this.email,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    authToken: authToken ?? this.authToken,
  );

  factory ChatwootContact.fromJson(Map<String, dynamic> json) =>
      _$ChatwootContactFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootContactToJson(this);

  @override
  List<Object?> get props => [
    id,
    contactIdentifier,
    pubsubToken,
    name,
    email,
    phoneNumber,
    authToken,
  ];

  @override
  String toString() => 'ChatwootContact(id: $id)';
}
