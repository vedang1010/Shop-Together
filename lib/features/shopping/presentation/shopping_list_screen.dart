import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user_model.dart';
import '../models/invite_model.dart';
import '../models/item_model.dart';
import '../repository/shopping_repository.dart';

class ShoppingListScreen extends StatelessWidget {
  final String listId;

  const ShoppingListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    final repository = ShoppingRepository();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go('/home');
          },
        ),
        title: StreamBuilder(
          stream: repository.getList(listId),
          builder: (context, snapshot) {
            final listName = snapshot.data?.name;

            return Text(
              listName == null || listName.isEmpty ? 'Shopping List' : listName,
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Add member',
            icon: const Icon(Icons.person_add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) {
                  return AddMemberDialog(
                    repository: repository,
                    listId: listId,
                  );
                },
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          CollaborationPanel(repository: repository, listId: listId),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ItemModel>>(
              stream: repository.getItems(listId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data!;
                final checkedCount = items
                    .where((item) => item.addedToCart)
                    .length;

                return Column(
                  children: [
                    ShoppingProgressHeader(
                      repository: repository,
                      listId: listId,
                      checkedCount: checkedCount,
                      totalCount: items.length,
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('No items yet'))
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];

                                return ListTile(
                                  leading: Icon(
                                    item.addedToCart
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: item.addedToCart
                                        ? Colors.green
                                        : item.isUrgent
                                        ? Colors.red
                                        : null,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            decoration: item.addedToCart
                                                ? TextDecoration.lineThrough
                                                : null,
                                            fontWeight: item.isUrgent
                                                ? FontWeight.w600
                                                : null,
                                          ),
                                        ),
                                      ),
                                      if (item.isUrgent)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(
                                            Icons.priority_high,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    item.notes.isEmpty
                                        ? 'Qty: ${item.quantity} - by ${item.addedByName}'
                                        : 'Qty: ${item.quantity} - ${item.notes}',
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        showDialog(
                                          context: context,
                                          builder: (_) {
                                            return EditItemDialog(
                                              repository: repository,
                                              listId: listId,
                                              item: item,
                                            );
                                          },
                                        );
                                      }

                                      if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (_) {
                                            return DeleteItemDialog(
                                              repository: repository,
                                              listId: listId,
                                              item: item,
                                            );
                                          },
                                        );
                                      }
                                    },
                                    itemBuilder: (context) {
                                      return const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ];
                                    },
                                  ),
                                  onTap: () {
                                    repository.toggleItem(
                                      listId: listId,
                                      itemId: item.id,
                                      currentValue: item.addedToCart,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,

            builder: (_) {
              return AddItemSheet(repository: repository, listId: listId);
            },
          );
        },

        child: const Icon(Icons.add),
      ),
    );
  }
}

class ShoppingProgressHeader extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final int checkedCount;
  final int totalCount;

  const ShoppingProgressHeader({
    super.key,
    required this.repository,
    required this.listId,
    required this.checkedCount,
    required this.totalCount,
  });

  @override
  State<ShoppingProgressHeader> createState() => _ShoppingProgressHeaderState();
}

class _ShoppingProgressHeaderState extends State<ShoppingProgressHeader> {
  bool isClearing = false;

  Future<void> clearCheckedItems() async {
    if (isClearing || widget.checkedCount == 0) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isClearing = true;
    });

    try {
      await widget.repository.clearCheckedItems(widget.listId);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Checked items cleared')),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isClearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalCount == 0
        ? 0.0
        : widget.checkedCount / widget.totalCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.checkedCount} / ${widget.totalCount} items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: widget.checkedCount == 0 || isClearing
                    ? null
                    : clearCheckedItems,
                icon: isClearing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cleaning_services),
                label: const Text('Clear checked'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }
}

class DuplicateItemWarning extends StatelessWidget {
  final String message;

  const DuplicateItemWarning({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class CollaborationPanel extends StatelessWidget {
  final ShoppingRepository repository;
  final String listId;

  const CollaborationPanel({
    super.key,
    required this.repository,
    required this.listId,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.group),
      title: const Text('Collaboration'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Members', style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AppUserModel>>(
          stream: repository.getListMembers(listId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final members = snapshot.data!;

            if (members.isEmpty) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text('No members found'),
              );
            }

            return Column(
              children: members.map((member) {
                final isCurrentUser = member.uid == repository.currentUserId;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: member.photoUrl == null
                        ? null
                        : NetworkImage(member.photoUrl!),
                    child: member.photoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(member.displayName),
                  subtitle: Text(member.email),
                  trailing: isCurrentUser
                      ? const Chip(label: Text('You'))
                      : IconButton(
                          tooltip: 'Remove member',
                          icon: const Icon(Icons.person_remove),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                return RemoveMemberDialog(
                                  repository: repository,
                                  listId: listId,
                                  member: member,
                                );
                              },
                            );
                          },
                        ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Invites', style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<InviteModel>>(
          stream: repository.getListInvites(listId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final invites = snapshot.data!;

            if (invites.isEmpty) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Text('No invites sent yet'),
              );
            }

            return Column(
              children: invites.map((invite) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_inviteStatusIcon(invite.status)),
                  title: Text(
                    invite.invitedEmail.isEmpty
                        ? invite.invitedUserId
                        : invite.invitedEmail,
                  ),
                  subtitle: Text('Invited by ${invite.invitedByName}'),
                  trailing: Chip(label: Text(invite.status)),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  IconData _inviteStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }
}

class RemoveMemberDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final AppUserModel member;

  const RemoveMemberDialog({
    super.key,
    required this.repository,
    required this.listId,
    required this.member,
  });

  @override
  State<RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<RemoveMemberDialog> {
  bool isRemoving = false;

  Future<void> removeMember() async {
    if (isRemoving) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isRemoving = true;
    });

    try {
      await widget.repository.removeMember(
        listId: widget.listId,
        userId: widget.member.uid,
      );

      if (!mounted) return;

      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Member removed')));
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isRemoving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remove Member'),
      content: Text('Remove ${widget.member.displayName} from this list?'),
      actions: [
        TextButton(
          onPressed: isRemoving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isRemoving ? null : removeMember,
          child: const Text('Remove'),
        ),
      ],
    );
  }
}

class AddItemSheet extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;

  const AddItemSheet({
    super.key,
    required this.repository,
    required this.listId,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class AddMemberDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;

  const AddMemberDialog({
    super.key,
    required this.repository,
    required this.listId,
  });

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class EditItemDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final ItemModel item;

  const EditItemDialog({
    super.key,
    required this.repository,
    required this.listId,
    required this.item,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class DeleteItemDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final ItemModel item;

  const DeleteItemDialog({
    super.key,
    required this.repository,
    required this.listId,
    required this.item,
  });

  @override
  State<DeleteItemDialog> createState() => _DeleteItemDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final searchController = TextEditingController();
  String query = '';
  String? invitingUserId;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Member'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name or email',
              ),
              onChanged: (value) {
                setState(() {
                  query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: StreamBuilder<List<AppUserModel>>(
                stream: widget.repository.getAvailableUsers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.where((user) {
                    if (query.isEmpty) return true;

                    final searchable = '${user.displayName} ${user.email}'
                        .toLowerCase();

                    return searchable.contains(query);
                  }).toList();

                  if (users.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isInviting = invitingUserId == user.uid;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoUrl == null
                              ? null
                              : NetworkImage(user.photoUrl!),
                          child: user.photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(user.email),
                        trailing: TextButton(
                          onPressed: invitingUserId == null
                              ? () => sendInvite(user)
                              : null,
                          child: isInviting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Invite'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: invitingUserId == null
              ? () => Navigator.pop(context)
              : null,
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> sendInvite(AppUserModel user) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      invitingUserId = user.uid;
    });

    try {
      await widget.repository.sendInvite(
        listId: widget.listId,
        invitedUser: user,
      );

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Invite sent to ${user.displayName}')),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          invitingUserId = null;
        });
      }
    }
  }
}

class _EditItemDialogState extends State<EditItemDialog> {
  late final TextEditingController nameController;
  late final TextEditingController qtyController;
  late final TextEditingController notesController;
  bool isSaving = false;
  late bool isUrgent;
  String? warningText;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item.name);
    qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    notesController = TextEditingController(text: widget.item.notes);
    isUrgent = widget.item.isUrgent;
  }

  Future<void> saveItem() async {
    final name = nameController.text.trim();
    final quantity = int.tryParse(qtyController.text) ?? 1;

    if (name.isEmpty || isSaving) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isSaving = true;
      warningText = null;
    });

    try {
      await widget.repository.updateItem(
        listId: widget.listId,
        itemId: widget.item.id,
        name: name,
        quantity: quantity,
        notes: notesController.text.trim(),
        isUrgent: isUrgent,
      );

      if (!mounted) return;

      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Item updated')));
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains('Another item already has this name')) {
        setState(() {
          warningText = 'Item already exists in this list';
        });
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            enabled: !isSaving,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Item name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: qtyController,
            enabled: !isSaving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            enabled: !isSaving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => saveItem(),
            decoration: const InputDecoration(hintText: 'Notes'),
          ),
          if (warningText != null) ...[
            const SizedBox(height: 12),
            DuplicateItemWarning(message: warningText!),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Urgent'),
            value: isUrgent,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      isUrgent = value;
                    });
                  },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isSaving ? null : saveItem,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteItemDialogState extends State<DeleteItemDialog> {
  bool isDeleting = false;

  Future<void> deleteItem() async {
    if (isDeleting) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isDeleting = true;
    });

    try {
      await widget.repository.deleteItem(
        listId: widget.listId,
        itemId: widget.item.id,
      );

      if (!mounted) return;

      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Item deleted')));
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Item'),
      content: Text('Delete "${widget.item.name}"?'),
      actions: [
        TextButton(
          onPressed: isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isDeleting ? null : deleteItem,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _AddItemSheetState extends State<AddItemSheet> {
  final nameController = TextEditingController();

  final qtyController = TextEditingController();

  final notesController = TextEditingController();

  bool isUrgent = false;
  bool isSaving = false;
  String? warningText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          TextField(
            controller: nameController,

            decoration: const InputDecoration(hintText: 'Item name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: qtyController,

            keyboardType: TextInputType.number,

            decoration: const InputDecoration(hintText: 'Quantity'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: notesController,

            decoration: const InputDecoration(hintText: 'Notes'),
          ),

          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Urgent'),
            value: isUrgent,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      isUrgent = value;
                    });
                  },
          ),

          if (warningText != null) ...[
            const SizedBox(height: 12),
            DuplicateItemWarning(message: warningText!),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
                    final name = nameController.text.trim();

                    final quantity = int.tryParse(qtyController.text) ?? 1;

                    if (name.isEmpty) return;

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    setState(() {
                      isSaving = true;
                      warningText = null;
                    });

                    try {
                      await widget.repository.addItem(
                        listId: widget.listId,
                        name: name,
                        quantity: quantity,
                        notes: notesController.text.trim(),
                        isUrgent: isUrgent,
                      );

                      if (!mounted) return;

                      navigator.pop();
                    } catch (e) {
                      if (!mounted) return;

                      final message = e.toString();

                      if (message.contains(
                        'Item already exists in this list',
                      )) {
                        setState(() {
                          warningText = 'Item already exists in this list';
                        });
                        return;
                      }

                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          isSaving = false;
                        });
                      }
                    }
                  },

            child: Text(isSaving ? 'Adding...' : 'Add Item'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
