import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListModel {
  final String id;
  final String name;
  final String createdBy;
  final Map<String, bool> members;
  final DateTime? createdAt;
  final DateTime? lastUpdated;

  ShoppingListModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory ShoppingListModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ShoppingListModel(
      id: id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      members: _membersFromData(data['members']),
      createdAt: _dateFromTimestamp(data['createdAt']),
      lastUpdated: _dateFromTimestamp(data['lastUpdated']),
    );
  }

  DateTime get sortDate => lastUpdated ?? createdAt ?? DateTime(0);

  static DateTime? _dateFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  static Map<String, bool> _membersFromData(dynamic value) {
    if (value is! Map) {
      return {};
    }

    return value.map((key, memberValue) {
      return MapEntry(key.toString(), memberValue == true);
    });
  }
}
