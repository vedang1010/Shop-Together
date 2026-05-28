import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shoptogether/features/shopping/models/item_model.dart';

import '../models/app_user_model.dart';
import '../models/invite_model.dart';
import '../models/shopping_list_model.dart';

class ShoppingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> createList(String name) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final uid = user.uid;

    await _firestore.collection('shopping_lists').add({
      'name': name,
      'createdBy': uid,
      'members': {uid: true},
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ShoppingListModel>> getLists() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('shopping_lists')
        .where('members.${user.uid}', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final lists = snapshot.docs.map((doc) {
            return ShoppingListModel.fromFirestore(doc.id, doc.data());
          }).toList();

          lists.sort((a, b) => b.sortDate.compareTo(a.sortDate));

          return lists;
        });
  }

  Stream<ShoppingListModel?> getList(String listId) {
    return _firestore.collection('shopping_lists').doc(listId).snapshots().map((
      doc,
    ) {
      final data = doc.data();

      if (!doc.exists || data == null) {
        return null;
      }

      return ShoppingListModel.fromFirestore(doc.id, data);
    });
  }

  Future<void> renameList({
    required String listId,
    required String name,
  }) async {
    await _firestore.collection('shopping_lists').doc(listId).update({
      'name': name,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteList(String listId) async {
    final listRef = _firestore.collection('shopping_lists').doc(listId);
    final items = await listRef.collection('items').get();
    final batch = _firestore.batch();

    for (final item in items.docs) {
      batch.delete(item.reference);
    }

    batch.delete(listRef);
    await batch.commit();
  }

  Future<void> addItem({
    required String listId,
    required String name,
    required int quantity,
    required String notes,
    required bool isUrgent,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final listRef = _firestore.collection('shopping_lists').doc(listId);
    final normalizedName = name.trim().toLowerCase();
    final existingItems = await listRef.collection('items').get();
    final hasDuplicate = existingItems.docs.any((doc) {
      final data = doc.data();
      final existingName = (data['name'] ?? '').toString().trim().toLowerCase();

      return existingName == normalizedName;
    });

    if (hasDuplicate) {
      throw Exception('Item already exists in this list');
    }

    await listRef.collection('items').add({
      'name': name,
      'quantity': quantity,
      'notes': notes,
      'isUrgent': isUrgent,
      'addedToCart': false,
      'addedBy': user.uid,
      'addedByName': user.displayName ?? 'User',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await listRef.update({'lastUpdated': FieldValue.serverTimestamp()});
  }

  Future<void> toggleItem({
    required String listId,
    required String itemId,
    required bool currentValue,
  }) async {
    final listRef = _firestore.collection('shopping_lists').doc(listId);

    await listRef.collection('items').doc(itemId).update({
      'addedToCart': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await listRef.update({'lastUpdated': FieldValue.serverTimestamp()});
  }

  Future<void> updateItem({
    required String listId,
    required String itemId,
    required String name,
    required int quantity,
    required String notes,
    required bool isUrgent,
  }) async {
    final listRef = _firestore.collection('shopping_lists').doc(listId);
    final normalizedName = name.trim().toLowerCase();
    final existingItems = await listRef.collection('items').get();
    final hasDuplicate = existingItems.docs.any((doc) {
      if (doc.id == itemId) return false;

      final data = doc.data();
      final existingName = (data['name'] ?? '').toString().trim().toLowerCase();

      return existingName == normalizedName;
    });

    if (hasDuplicate) {
      throw Exception('Another item already has this name');
    }

    await listRef.collection('items').doc(itemId).update({
      'name': name,
      'quantity': quantity,
      'notes': notes,
      'isUrgent': isUrgent,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await listRef.update({'lastUpdated': FieldValue.serverTimestamp()});
  }

  Future<void> deleteItem({
    required String listId,
    required String itemId,
  }) async {
    final listRef = _firestore.collection('shopping_lists').doc(listId);

    await listRef.collection('items').doc(itemId).delete();

    await listRef.update({'lastUpdated': FieldValue.serverTimestamp()});
  }

  Stream<List<ItemModel>> getItems(String listId) {
    return _firestore
        .collection('shopping_lists')
        .doc(listId)
        .collection('items')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            return ItemModel.fromFirestore(doc.id, doc.data());
          }).toList();

          items.sort((a, b) {
            if (a.addedToCart != b.addedToCart) {
              return a.addedToCart ? 1 : -1;
            }

            if (a.isUrgent != b.isUrgent) {
              return a.isUrgent ? -1 : 1;
            }

            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return items;
        });
  }

  Future<void> clearCheckedItems(String listId) async {
    final listRef = _firestore.collection('shopping_lists').doc(listId);
    final checkedItems = await listRef
        .collection('items')
        .where('addedToCart', isEqualTo: true)
        .get();

    if (checkedItems.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final item in checkedItems.docs) {
      batch.delete(item.reference);
    }

    batch.update(listRef, {'lastUpdated': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Stream<List<AppUserModel>> getAvailableUsers() {
    final currentUserId = _auth.currentUser?.uid;

    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUserModel.fromFirestore(doc.id, doc.data()))
          .where((user) => user.uid != currentUserId)
          .toList();
    });
  }

  Stream<List<AppUserModel>> getListMembers(String listId) {
    return getList(listId).asyncMap((list) async {
      if (list == null) return <AppUserModel>[];

      final memberIds = list.members.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (memberIds.isEmpty) return <AppUserModel>[];

      final users = await Future.wait(
        memberIds.map((memberId) async {
          final doc = await _firestore.collection('users').doc(memberId).get();
          final data = doc.data();

          if (!doc.exists || data == null) return null;

          return AppUserModel.fromFirestore(doc.id, data);
        }),
      );

      final members = users.whereType<AppUserModel>().toList();
      members.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      return members;
    });
  }

  Future<void> removeMember({
    required String listId,
    required String userId,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception("User not logged in");
    }

    if (currentUser.uid == userId) {
      throw Exception('You cannot remove yourself');
    }

    await _firestore.collection('shopping_lists').doc(listId).update({
      'members.$userId': FieldValue.delete(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendInvite({
    required String listId,
    required AppUserModel invitedUser,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception("User not logged in");
    }

    final listDoc = await _firestore
        .collection('shopping_lists')
        .doc(listId)
        .get();
    final list = listDoc.data();

    if (!listDoc.exists || list == null) {
      throw Exception('List not found');
    }

    final members = Map<String, dynamic>.from(list['members'] ?? {});

    if (members[invitedUser.uid] == true) {
      throw Exception('User is already a member');
    }

    final existingInvite = await _firestore
        .collection('invites')
        .where('listId', isEqualTo: listId)
        .where('invitedUserId', isEqualTo: invitedUser.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingInvite.docs.isNotEmpty) {
      throw Exception('Invite already sent');
    }

    await _firestore.collection('invites').add({
      'listId': listId,
      'listName': list['name'] ?? 'Shopping List',
      'invitedUserId': invitedUser.uid,
      'invitedEmail': invitedUser.email,
      'invitedByUserId': currentUser.uid,
      'invitedByName':
          currentUser.displayName ?? currentUser.email ?? 'Someone',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
  }

  Stream<List<InviteModel>> getListInvites(String listId) {
    return _firestore
        .collection('invites')
        .where('listId', isEqualTo: listId)
        .snapshots()
        .map((snapshot) {
          final invites = snapshot.docs.map((doc) {
            return InviteModel.fromFirestore(doc.id, doc.data());
          }).toList();

          invites.sort((a, b) {
            if (a.status == b.status) {
              return a.invitedEmail.compareTo(b.invitedEmail);
            }

            if (a.status == 'pending') return -1;
            if (b.status == 'pending') return 1;

            return a.status.compareTo(b.status);
          });

          return invites;
        });
  }

  Stream<List<InviteModel>> getPendingInvites() {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('invites')
        .where('invitedUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return InviteModel.fromFirestore(doc.id, doc.data());
          }).toList();
        });
  }

  Future<void> acceptInvite(InviteModel invite) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception("User not logged in");
    }

    final batch = _firestore.batch();
    final listRef = _firestore.collection('shopping_lists').doc(invite.listId);
    final inviteRef = _firestore.collection('invites').doc(invite.id);

    batch.update(listRef, {
      'members.${currentUser.uid}': true,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    batch.update(inviteRef, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineInvite(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }
}
