import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactAvatar extends StatelessWidget {
  final String? contactId;
  final String? photoUri;
  final String? localPhotoPath;
  final String? phoneNumber;
  final String? fallbackName;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ContactAvatar({
    super.key,
    this.contactId,
    this.photoUri,
    this.localPhotoPath,
    this.phoneNumber,
    this.fallbackName,
    this.radius = 24.0,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: _getAvatarProvider(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFallback(context, isLoading: true);
        }

        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: snapshot.data,
            backgroundColor:
                backgroundColor ?? Theme.of(context).primaryColorDark,
          );
        }

        return _buildFallback(context, isLoading: false);
      },
    );
  }

  static final Map<String, Future<ImageProvider?>> _avatarCache = {};

  Future<ImageProvider?> _getAvatarProvider() {
    final cacheKey = '${contactId ?? ''}_${phoneNumber ?? ''}_${localPhotoPath ?? ''}';
    if (cacheKey == '__') return Future.value(null);

    if (_avatarCache.containsKey(cacheKey)) {
      return _avatarCache[cacheKey]!;
    }

    final future = _loadAvatar();
    _avatarCache[cacheKey] = future;
    return future;
  }

  Future<ImageProvider?> _loadAvatar() async {
    // 1. Try local explicitly picked image path
    if (localPhotoPath != null && localPhotoPath!.isNotEmpty) {
      final file = File(localPhotoPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return MemoryImage(bytes);
      }
    }

    // 1b. Try file-based photoUri when available.
    if (photoUri != null && photoUri!.isNotEmpty) {
      final uri = photoUri!.trim();
      if (uri.startsWith('file://')) {
        final file = File(Uri.parse(uri).toFilePath());
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return MemoryImage(bytes);
        }
      } else {
        final file = File(uri);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return MemoryImage(bytes);
        }
      }
    }

    // 2. Try fetching full contact details for existing contacts
    if (contactId != null && contactId!.isNotEmpty) {
      try {
        if (await FlutterContacts.requestPermission(readonly: true)) {
          final contact = await FlutterContacts.getContact(
            contactId!,
            withPhoto: true,
            withThumbnail: true,
          );
          if (contact != null) {
            if (contact.photo != null && contact.photo!.isNotEmpty) {
              return MemoryImage(contact.photo!);
            }
            if (contact.thumbnail != null && contact.thumbnail!.isNotEmpty) {
              return MemoryImage(contact.thumbnail!);
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading contact native avatar: $e");
      }
    }

    // 3. Automated Photo Sync: Lookup by Phone Number if no ID provided
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      try {
        if (await FlutterContacts.requestPermission(readonly: true)) {
          // Normalize the search number (only digits)
          final searchNum = phoneNumber!.replaceAll(RegExp(r'\D'), '');
          if (searchNum.length >= 10) {
            final contacts = await FlutterContacts.getContacts(
              withProperties: true,
              withThumbnail: true,
            );

            for (final contact in contacts) {
              for (final phone in contact.phones) {
                final normalized = phone.number.replaceAll(RegExp(r'\D'), '');
                if (normalized.contains(searchNum) ||
                    searchNum.contains(normalized)) {
                  if (contact.photo != null && contact.photo!.isNotEmpty) {
                    return MemoryImage(contact.photo!);
                  }
                  if (contact.thumbnail != null &&
                      contact.thumbnail!.isNotEmpty) {
                    return MemoryImage(contact.thumbnail!);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error looking up contact by number: $e");
      }
    }

    return null;
  }

  Widget _buildFallback(BuildContext context, {required bool isLoading}) {
    // Determine the letter to show
    String initial = "?";
    if (fallbackName != null && fallbackName!.trim().isNotEmpty) {
      initial = fallbackName!.trim()[0].toUpperCase();
    }

    final theme = Theme.of(context);

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.2),
      foregroundColor: foregroundColor ?? theme.colorScheme.primary,
      child: isLoading
          ? SizedBox(
              width: radius,
              height: radius,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          : Text(
              initial,
              style: TextStyle(fontSize: radius, fontWeight: FontWeight.bold),
            ),
    );
  }
}
