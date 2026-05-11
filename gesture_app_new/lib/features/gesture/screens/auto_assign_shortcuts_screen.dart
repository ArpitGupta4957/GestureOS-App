import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/gesture_provider.dart';
import 'package:gesture_app/core/models/gesture_model.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class AutoAssignShortcutsScreen extends ConsumerStatefulWidget {
  const AutoAssignShortcutsScreen({super.key});

  @override
  ConsumerState<AutoAssignShortcutsScreen> createState() =>
      _AutoAssignShortcutsScreenState();
}

class _AutoAssignShortcutsScreenState
    extends ConsumerState<AutoAssignShortcutsScreen> {
  int _currentStep = 0;
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedContactIds = {};
  bool _isLoading = true;
  int _shortcutLength = 2; // Default 2 chars
  List<Map<String, dynamic>> _generatedShortcuts = [];
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _filterMode = 'All'; // 'All', 'Selected', 'Unselected'

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final aliasedIds = _getAliasedContactIds();
    setState(() {
      _filteredContacts = _allContacts.where((c) {
        final matchesSearch = c.displayName.toLowerCase().contains(query);
        if (!matchesSearch) return false;

        final isSelected = _selectedContactIds.contains(c.id);
        final isAliased = aliasedIds.contains(c.id);
        if (_filterMode == 'Selected' && !isSelected) return false;
        if (_filterMode == 'Unselected' && isSelected) return false;
        if (_filterMode == 'Aliased' && !isAliased) return false;

        return true;
      }).toList();
    });
  }

  Future<void> _fetchContacts() async {
    PermissionStatus status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }

    if (status.isGranted) {
      // Double check with FlutterContacts just in case
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        // This sometimes happens on specific ROMs
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: true,
      );
      // Filter only those with phone numbers
      final validContacts = contacts
          .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _allContacts = validContacts;
          _isLoading = false;
        });
        _applyFilters();
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Permission Required"),
            content: const Text(
              "Contacts permission is needed to generate shortcuts. Please enable it in settings.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text("Open Settings"),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Permission denied')));
      }
    }
  }

  void _generateShortcuts() {
    final selected = _allContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();
    if (selected.isEmpty) return;

    final existingGestures = ref.read(gestureProvider).gestures;
    final existingTriggers = existingGestures
        .map((g) => g.triggerText?.toLowerCase() ?? '')
        .toSet();
    final generated = <Map<String, dynamic>>[];

    for (var contact in selected) {
      // Explicitly construct name using first/last to avoid OEM truncation bugs in displayName
      String name =
          "${contact.name.first} ${contact.name.middle} ${contact.name.last}"
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty) {
        name = contact.displayName;
      }

      final number = contact.phones.first.number;

      // Extract words, removing non-alphabetic characters except spaces, then split by space
      final words = name
          .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isEmpty) continue; // Skip if no valid letters

      String shortcut = "";

      // Build shortcut by taking first letter of each word,
      // then filling remaining length from words that have extra characters
      if (words.length >= _shortcutLength) {
        // Enough words: take first letter of each word
        shortcut = words.take(_shortcutLength).map((w) => w[0]).join();
      } else {
        // Not enough words: take first letter of each word first
        List<String> chars = words.map((w) => w[0]).toList();

        // Fill remaining characters from words that have extra letters
        int remaining = _shortcutLength - chars.length;
        for (int wi = 0; wi < words.length && remaining > 0; wi++) {
          if (words[wi].length > 1) {
            int extraAvail = words[wi].length - 1; // chars beyond first letter
            int take = extraAvail.clamp(0, remaining);
            // Insert extra chars right after this word's first letter
            for (int ci = 0; ci < take && remaining > 0; ci++) {
              // Find where this word's initial is in our chars list
              int wordInitialIdx = wi;
              for (int ahead = 0; ahead < ci; ahead++) {
                wordInitialIdx++; // account for previously inserted chars
              }
              chars.insert(wordInitialIdx + 1 + ci, words[wi][1 + ci]);
              remaining--;
            }
          }
        }

        shortcut = chars.join();
      }

      // Ensure exact length
      if (shortcut.length > _shortcutLength) {
        shortcut = shortcut.substring(0, _shortcutLength);
      }

      // If somehow logic failed or word constraints were weird
      if (shortcut.isEmpty) {
        shortcut = name.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
        if (shortcut.length > _shortcutLength) {
          shortcut = shortcut.substring(0, _shortcutLength);
        }
      }

      // Handle duplicates: first gets no suffix, then 2, 3, 4...
      String candidate = shortcut;
      int counter = 2;
      while (existingTriggers.contains(candidate) ||
          generated.any((g) => g['shortcut'] == candidate)) {
        candidate = "$shortcut$counter";
        counter++;
      }

      generated.add({
        'name': name,
        'number': number,
        'shortcut': candidate,
        'original_contact': contact,
        'controller': TextEditingController(text: candidate), // For editing
      });
    }

    setState(() {
      _generatedShortcuts = generated;
      _currentStep = 1;
    });
  }

  /// Check if a shortcut text conflicts with existing triggers or other items in batch
  bool _isShortcutConflicting(int itemIndex) {
    final controller =
        _generatedShortcuts[itemIndex]['controller'] as TextEditingController;
    final value = controller.text.trim().toLowerCase();
    if (value.isEmpty) return false;

    // Check against existing gestures
    final existingGestures = ref.read(gestureProvider).gestures;
    final existingTriggers = existingGestures
        .map((g) => g.triggerText?.toLowerCase() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();
    if (existingTriggers.contains(value)) return true;

    // Check against other items in the same batch
    for (int i = 0; i < _generatedShortcuts.length; i++) {
      if (i == itemIndex) continue;
      final otherVal =
          (_generatedShortcuts[i]['controller'] as TextEditingController).text
              .trim()
              .toLowerCase();
      if (otherVal == value) return true;
    }
    return false;
  }

  /// Get set of already aliased contact IDs
  Set<String> _getAliasedContactIds() {
    final existingGestures = ref.read(gestureProvider).gestures;
    return existingGestures
        .where(
          (g) =>
              g.actionType.toUpperCase() == 'CALL' &&
              g.contactId != null &&
              g.contactId!.isNotEmpty,
        )
        .map((g) => g.contactId!)
        .toSet();
  }

  Future<void> _saveAll() async {
    // Check for conflicts before saving
    bool hasConflicts = false;
    for (int i = 0; i < _generatedShortcuts.length; i++) {
      if (_isShortcutConflicting(i)) {
        hasConflicts = true;
        break;
      }
    }
    if (hasConflicts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some shortcuts conflict (shown in red). Please fix them before saving.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {}); // Trigger rebuild to show red highlights
      return;
    }

    setState(() => _isSaving = true);
    int savedCount = 0;

    for (var item in _generatedShortcuts) {
      final shortcut = (item['controller'] as TextEditingController).text
          .trim()
          .toLowerCase();
      if (shortcut.isEmpty) continue;

      final number = item['number'];
      final name = item['name'];
      final originalContact = item['original_contact'] as Contact;

      final newGesture = GestureModel(
        id: null,
        uuid: const Uuid().v4(),
        name: "Call $name",
        triggerText: shortcut,
        points: [], // No drawing
        actionType: 'CALL',
        actionValue: number,
        contactId: originalContact.id,
        isFavorite: false,
        createdAt: DateTime.now(),
      );

      await ref.read(gestureProvider.notifier).saveGesture(newGesture);
      savedCount++;
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $savedCount shortcuts!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) return _buildContactSelection();
    return _buildReviewStep();
  }

  Widget _buildContactSelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Contacts"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedContactIds.length == _filteredContacts.length) {
                  _selectedContactIds.clear();
                } else {
                  _selectedContactIds = _filteredContacts
                      .map((c) => c.id)
                      .toSet();
                }
              });
            },
            child: Text(
              _selectedContactIds.length == _filteredContacts.length &&
                      _filteredContacts.isNotEmpty
                  ? "Deselect All"
                  : "Select All",
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedContactIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLengthPicker();
                  },
                  label: Text("Next (${_selectedContactIds.length})"),
                  icon: const Icon(Icons.arrow_forward),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Search Contacts",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _applyFilters(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Selected', label: Text('Selected')),
                  ButtonSegment(value: 'Unselected', label: Text('Unselected')),
                  ButtonSegment(value: 'Aliased', label: Text('Aliased')),
                ],
                selected: {_filterMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _filterMode = newSelection.first;
                  });
                  _applyFilters();
                },
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final isSelected = _selectedContactIds.contains(
                        contact.id,
                      );
                      final aliasedIds = _getAliasedContactIds();
                      final isAliased = aliasedIds.contains(contact.id);
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isAliased ? true : isSelected,
                              onChanged: isAliased
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedContactIds.add(contact.id);
                                        } else {
                                          _selectedContactIds.remove(
                                            contact.id,
                                          );
                                        }
                                      });
                                      _applyFilters();
                                    },
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundImage:
                                  contact.thumbnail != null &&
                                      contact.thumbnail!.isNotEmpty
                                  ? MemoryImage(contact.thumbnail!)
                                  : null,
                              backgroundColor: isAliased
                                  ? Colors.grey.withOpacity(0.2)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.15),
                              child:
                                  contact.thumbnail == null ||
                                      contact.thumbnail!.isEmpty
                                  ? Text(
                                      contact.displayName.isNotEmpty
                                          ? contact.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: isAliased
                                            ? Colors.grey
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.displayName,
                                style: TextStyle(
                                  color: isAliased ? Colors.grey : null,
                                ),
                              ),
                            ),
                            if (isAliased)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ALIASED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          contact.phones.isNotEmpty
                              ? contact.phones.first.number
                              : '',
                          style: TextStyle(
                            color: isAliased
                                ? Colors.grey.withOpacity(0.5)
                                : null,
                          ),
                        ),
                        onTap: isAliased
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedContactIds.remove(contact.id);
                                  } else {
                                    _selectedContactIds.add(contact.id);
                                  }
                                });
                                _applyFilters();
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showLengthPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow it to take up more space if needed
      builder: (ctx) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Shortcut Length",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [2, 3, 4]
                    .map(
                      (len) => ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _shortcutLength = len);
                          _generateShortcuts();
                        },
                        child: Text("$len Letters"),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Review (${_generatedShortcuts.length})"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentStep = 0),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.tune, size: 18),
            label: Text('$_shortcutLength Letters'),
            onPressed: _showLengthPicker,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving shortcuts...'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _generatedShortcuts.length,
              itemBuilder: (context, index) {
                final item = _generatedShortcuts[index];
                return Dismissible(
                  key: ValueKey(item['number']),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() => _generatedShortcuts.removeAt(index));
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        // Contact avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.15),
                          child: Text(
                            (item['name'] as String).isNotEmpty
                                ? (item['name'] as String)[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + number
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['number'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Editable alias with conflict highlighting
                        Builder(
                          builder: (ctx) {
                            final isConflict = _isShortcutConflicting(index);
                            return SizedBox(
                              width: 110,
                              child: TextField(
                                controller: item['controller'],
                                textAlign: TextAlign.center,
                                onChanged: (_) => setState(
                                  () {},
                                ), // Rebuild to check conflicts
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isConflict
                                      ? Colors.red
                                      : theme.colorScheme.primary,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isConflict
                                      ? Colors.red.withOpacity(0.1)
                                      : theme.colorScheme.primary.withOpacity(
                                          0.08,
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: isConflict
                                        ? const BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          )
                                        : BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: isConflict
                                        ? const BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          )
                                        : BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isConflict
                                          ? Colors.red
                                          : theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      (item['controller']
                                              as TextEditingController)
                                          .clear();
                                      setState(() {});
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isSaving || _generatedShortcuts.isEmpty ? null : _saveAll,
          icon: const Icon(Icons.check_circle_rounded),
          label: Text("SAVE ${_generatedShortcuts.length} SHORTCUTS"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
