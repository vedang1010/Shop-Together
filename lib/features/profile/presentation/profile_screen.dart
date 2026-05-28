import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/repository/auth_repository.dart';
import '../../shopping/models/invite_model.dart';
import '../../shopping/repository/shopping_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authRepository = AuthRepository();
    final shoppingRepository = ShoppingRepository();

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
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: user?.photoURL == null
                      ? null
                      : NetworkImage(user!.photoURL!),
                  child: user?.photoURL == null
                      ? const Icon(Icons.person, size: 42)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(user?.email ?? ''),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await authRepository.signOut();

                    if (!context.mounted) return;

                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Invites', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          StreamBuilder<List<InviteModel>>(
            stream: shoppingRepository.getPendingInvites(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final invites = snapshot.data!;

              if (invites.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No pending invites')),
                );
              }

              return Column(
                children: invites.map((invite) {
                  return InviteTile(
                    invite: invite,
                    repository: shoppingRepository,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class InviteTile extends StatefulWidget {
  final InviteModel invite;
  final ShoppingRepository repository;

  const InviteTile({super.key, required this.invite, required this.repository});

  @override
  State<InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends State<InviteTile> {
  bool isSaving = false;

  Future<void> acceptInvite() async {
    if (isSaving) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isSaving = true;
    });

    try {
      await widget.repository.acceptInvite(widget.invite);

      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('Invite accepted')));
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

  Future<void> declineInvite() async {
    if (isSaving) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isSaving = true;
    });

    try {
      await widget.repository.declineInvite(widget.invite.id);

      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('Invite declined')));
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
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.invite.listName),
        subtitle: Text('Invited by ${widget.invite.invitedByName}'),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Decline',
              onPressed: isSaving ? null : declineInvite,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              tooltip: 'Accept',
              onPressed: isSaving ? null : acceptInvite,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
