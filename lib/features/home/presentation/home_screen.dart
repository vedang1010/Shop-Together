import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoptogether/features/auth/repository/auth_repository.dart';
import 'package:shoptogether/features/shopping/models/shopping_list_model.dart';

import '../../shopping/repository/shopping_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ShoppingRepository();
    final authRepository = AuthRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Lists'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authRepository.signOut();

              if (!context.mounted) return;

              context.go('/login');
            },
          ),
        ],
      ),

      body: StreamBuilder(
        stream: repository.getLists(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lists = snapshot.data ?? <ShoppingListModel>[];
          if (lists.isEmpty) {
            return const Center(child: Text('No lists yet'));
          }

          return ListView.builder(
            itemCount: lists.length,

            itemBuilder: (context, index) {
              final list = lists[index];

              return ListTile(
                title: Text(list.name),

                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      showDialog(
                        context: context,
                        builder: (_) {
                          return RenameListDialog(
                            repository: repository,
                            listId: list.id,
                            currentName: list.name,
                          );
                        },
                      );
                    }

                    if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (_) {
                          return DeleteListDialog(
                            repository: repository,
                            listId: list.id,
                            listName: list.name,
                          );
                        },
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ];
                  },
                ),

                onTap: () {
                  context.push('/shopping/${list.id}');
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) {
              return CreateListDialog(repository: repository);
            },
          );
        },

        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreateListDialog extends StatefulWidget {
  final ShoppingRepository repository;

  const CreateListDialog({super.key, required this.repository});

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();
}

class RenameListDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final String currentName;

  const RenameListDialog({
    super.key,
    required this.repository,
    required this.listId,
    required this.currentName,
  });

  @override
  State<RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<RenameListDialog> {
  late final TextEditingController controller;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.currentName);
  }

  Future<void> renameList() async {
    final name = controller.text.trim();

    if (name.isEmpty || isSaving) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isSaving = true;
    });

    try {
      await widget.repository.renameList(listId: widget.listId, name: name);

      if (!mounted) return;

      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('List renamed')));
    } catch (e) {
      if (!mounted) return;

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
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename List'),
      content: TextField(
        controller: controller,
        enabled: !isSaving,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => renameList(),
        decoration: const InputDecoration(hintText: 'List name'),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isSaving ? null : renameList,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class DeleteListDialog extends StatefulWidget {
  final ShoppingRepository repository;
  final String listId;
  final String listName;

  const DeleteListDialog({
    super.key,
    required this.repository,
    required this.listId,
    required this.listName,
  });

  @override
  State<DeleteListDialog> createState() => _DeleteListDialogState();
}

class _DeleteListDialogState extends State<DeleteListDialog> {
  bool isDeleting = false;

  Future<void> deleteList() async {
    if (isDeleting) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isDeleting = true;
    });

    try {
      await widget.repository.deleteList(widget.listId);

      if (!mounted) return;

      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('List deleted')));
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
      title: const Text('Delete List'),
      content: Text('Delete "${widget.listName}" and all of its items?'),
      actions: [
        TextButton(
          onPressed: isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isDeleting ? null : deleteList,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _CreateListDialogState extends State<CreateListDialog> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create List'),

      content: TextField(
        controller: controller,
        textInputAction: TextInputAction.done,

        onSubmitted: (value) {
          final name = value.trim();
          if (name.isEmpty) return;

          Navigator.of(context, rootNavigator: true).pop();

          widget.repository.createList(name);
        },

        decoration: const InputDecoration(hintText: 'List name'),
      ),

      actions: [
        TextButton(
          onPressed: () async {
            final name = controller.text.trim();

            if (name.isEmpty) return;

            final navigator = Navigator.of(context, rootNavigator: true);
            final messenger = ScaffoldMessenger.of(context);

            try {
              await widget.repository.createList(name);

              if (!context.mounted) return;

              navigator.pop();
            } catch (e) {
              if (!context.mounted) return;

              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },

          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
