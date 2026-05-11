import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/gesture_provider.dart';
import 'package:gesture_app/core/widgets/contact_avatar.dart';

class AliasedContactsTab extends ConsumerStatefulWidget {
  const AliasedContactsTab({super.key});

  @override
  ConsumerState<AliasedContactsTab> createState() => _AliasedContactsTabState();
}

class _AliasedContactsTabState extends ConsumerState<AliasedContactsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final gestureState = ref.watch(gestureProvider);
    final theme = Theme.of(context);

    if (gestureState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gestureState.error != null) {
      return Center(
        child: Text(
          'Error loading shortcuts',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    // Filter to only show actions that are "CALL" and have a shortcut assigned (triggerText)
    var aliasedContacts = gestureState.gestures.where((g) {
      return g.actionType.toUpperCase() == 'CALL' &&
          g.triggerText != null &&
          g.triggerText!.isNotEmpty;
    }).toList();

    // Apply search filter: match by contact name, alias (triggerText), or number
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      aliasedContacts = aliasedContacts.where((g) {
        final name = _formatName(g.name).toLowerCase();
        final alias = g.triggerText?.toLowerCase() ?? '';
        final number = g.actionValue.toLowerCase();
        return name.contains(query) ||
            alias.contains(query) ||
            number.contains(query);
      }).toList();
    }

    if (gestureState.gestures
        .where(
          (g) =>
              g.actionType.toUpperCase() == 'CALL' &&
              g.triggerText != null &&
              g.triggerText!.isNotEmpty,
        )
        .isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_phone_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text('No Aliased Contacts', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Create a call shortcut to see it here.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by name, alias, or number...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),

        // Results
        Expanded(
          child: aliasedContacts.isEmpty
              ? const Center(
                  child: Text(
                    'No matches found',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: aliasedContacts.length,
                  itemBuilder: (context, index) {
                    final gesture = aliasedContacts[index];
                    final name = _formatName(gesture.name);
                    final number = gesture.actionValue;
                    final alias = gesture.triggerText ?? '';

                    return Dismissible(
                      key: ValueKey(gesture.uuid),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Shortcut?"),
                            content: Text("Remove shortcut for $name?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("CANCEL"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text("DELETE"),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        ref
                            .read(gestureProvider.notifier)
                            .deleteGesture(gesture.uuid);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Shortcut removed for $name'),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: ContactAvatar(
                          fallbackName: name.isNotEmpty ? name : '?',
                          localPhotoPath: gesture.localPhotoPath,
                          contactId: gesture.contactId,
                          phoneNumber: gesture.actionValue,
                          radius: 24,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          number,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                alias,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.edit_rounded,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                              onPressed: () {
                                context.push('/draw-gesture', extra: gesture);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatName(String rawName) {
    if (rawName.toLowerCase().startsWith('call ')) {
      return rawName.substring(5);
    }
    return rawName;
  }
}
