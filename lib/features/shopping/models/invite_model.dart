class InviteModel {
  final String id;
  final String listId;
  final String listName;
  final String invitedUserId;
  final String invitedEmail;
  final String invitedByUserId;
  final String invitedByName;
  final String status;

  InviteModel({
    required this.id,
    required this.listId,
    required this.listName,
    required this.invitedUserId,
    required this.invitedEmail,
    required this.invitedByUserId,
    required this.invitedByName,
    required this.status,
  });

  factory InviteModel.fromFirestore(String id, Map<String, dynamic> data) {
    return InviteModel(
      id: id,
      listId: data['listId'] ?? '',
      listName: data['listName'] ?? 'Shopping List',
      invitedUserId: data['invitedUserId'] ?? '',
      invitedEmail: data['invitedEmail'] ?? '',
      invitedByUserId: data['invitedByUserId'] ?? '',
      invitedByName: data['invitedByName'] ?? 'Someone',
      status: data['status'] ?? 'pending',
    );
  }
}
