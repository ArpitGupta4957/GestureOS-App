import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/api/api_service.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:gesture_app/core/database/database_helper.dart';
import 'package:gesture_app/core/models/gesture_model.dart';
// Note: GestureModel is now imported, not defined inline.

/// Gesture state
class GestureState {
  final List<GestureModel> gestures;
  final bool isLoading;
  final String? error;
  final bool isSyncing;

  GestureState({
    this.gestures = const [],
    this.isLoading = false,
    this.error,
    this.isSyncing = false,
  });

  GestureState copyWith({
    List<GestureModel>? gestures,
    bool? isLoading,
    String? error,
    bool? isSyncing,
    bool clearError = false,
  }) {
    return GestureState(
      gestures: gestures ?? this.gestures,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Gesture provider for managing user gestures (Offline First)
class GestureNotifier extends StateNotifier<GestureState> {
  final ApiService _apiService;
  final Ref _ref;
  final DatabaseHelper _db = DatabaseHelper();

  GestureNotifier(this._apiService, this._ref) : super(GestureState()) {
    // Load gestures from local database (preserves data across restarts)
    _loadGestures();
  }

  /// Load gestures from LOCAL SQLite (Fast)
  Future<void> _loadGestures() async {
    print('🚀 [GestureProvider] _loadGestures() CALLED');

    // We don't necessarily block on Auth for local data,
    // but maybe we should clear data on logout.
    // For now, load what's in DB.

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final gestures = await _db.getAllGestures();
      print('📦 [Offline] Loaded ${gestures.length} gestures from SQLite');

      // Debug: Log each gesture's point count
      for (var g in gestures) {
        print('   → ${g.name}: ${g.points.length} points');
      }

      state = state.copyWith(gestures: gestures, isLoading: false);

      // SYNC WITH OVERLAY
      print('🔄 [GestureProvider] Calling OverlayService.updateGestures...');
      OverlayService.updateGestures(gestures);

      // Trigger Background Sync if online
      _syncInBackground();
    } catch (e) {
      print('❌ Failed to load local gestures: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load local data: $e',
      );
    }
  }

  /// Refresh gestures (Trigger Sync)
  Future<void> refreshGestures() async {
    print('🔄 [refreshGestures] START');

    // FORCE RESET SYNC STATUS to ensure local data is pushed to server
    print('🔄 [refreshGestures] Resetting sync status...');
    await _db.resetSyncStatus();

    // Check how many pending after reset
    final pendingAfterReset = await _db.getPendingSync();
    print(
      '🔄 [refreshGestures] After reset: ${pendingAfterReset.length} pending items',
    );

    // Reload local first
    print('🔄 [refreshGestures] Loading gestures...');
    await _loadGestures();

    // Force Sync
    print('🔄 [refreshGestures] Starting sync...');
    await _syncInBackground();
    print('🔄 [refreshGestures] DONE');
  }

  /// Force complete re-sync (Smart Merge)
  Future<void> forceResync() async {
    print('🔥 [GestureProvider] forceResync() - Starting Smart Sync...');
    // REMOVED: await _db.clearAllGestures(); -> This was the bug causing data loss!

    state = state.copyWith(isLoading: true);

    // Pull fresh from server
    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated) {
      print('❌ [GestureProvider] Not authenticated, cannot sync');
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      // 1. Sync Deletes First
      await _syncDeletedGestures();

      // 2. Push Pending
      // (Optional for Force Sync, but good practice to clear queue)
      final pending = await _db.getPendingSync();
      if (pending.isNotEmpty) {
        print('📤 [ForceSync] Pushing ${pending.length} pending gestures...');
        final payload = pending.map((g) => g.toJson()).toList();
        print('📤 [ForceSync] Payload sample: ${payload.first}');
        final pushResponse = await _apiService.syncGestures(payload);
        print(
          '📤 [ForceSync] Push Response: success=${pushResponse.success}, msg=${pushResponse.message}',
        );
        if (pushResponse.data != null) {
          print('📤 [ForceSync] Response data: ${pushResponse.data}');
        }

        if (pushResponse.success) {
          for (var g in pending) {
            await _db.markAsSynced(g.uuid);
          }
          print(
            '✅ [ForceSync] Push complete - ${pending.length} items marked as synced',
          );
        } else {
          print('❌ [ForceSync] Push FAILED: ${pushResponse.message}');
        }
      } else {
        print('ℹ️ [ForceSync] No pending items to push');
      }

      // 3. Pull from Server (DatabaseHelper.upsertFromServer will handle conflicts)
      print('📥 [GestureProvider] Pulling fresh data from server...');
      final pullResponse = await _apiService.getGestures();
      if (pullResponse.success && pullResponse.data != null) {
        final serverList = pullResponse.data!['gestures'] as List;
        await _db.upsertFromServer(serverList);
        print(
          '✅ [GestureProvider] Smart sync complete (${serverList.length} items from server)',
        );

        final freshGestures = await _db.getAllGestures();
        state = state.copyWith(gestures: freshGestures, isLoading: false);
        OverlayService.updateGestures(freshGestures);
      } else {
        print('❌ [GestureProvider] Pull failed: ${pullResponse.message}');
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      print('❌ [GestureProvider] Force sync error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Background Sync Logic (Push & Pull)
  Future<void> _syncInBackground() async {
    final authState = _ref.read(authProvider);
    print("🔐 [Sync] Check Auth: isAuthenticated=${authState.isAuthenticated}");
    if (!authState.isAuthenticated) {
      print("❌ [Sync] Skipped: Not Authenticated");
      return;
    }

    if (state.isSyncing) return; // Prevent concurrent syncs
    // state = state.copyWith(isSyncing: true); // Optional: show spinner? Maybe just silent.

    try {
      print("🔄 [Sync] Starting Background Sync...");

      // 0. SYNC DELETES FIRST - Before push/pull
      await _syncDeletedGestures();

      // 1. PUSH: Get pending items
      final pending = await _db.getPendingSync();
      if (pending.isNotEmpty) {
        print("📤 [Sync] Pushing ${pending.length} local changes...");
        final payload = pending.map((g) => g.toJson()).toList();
        print("📤 [Sync] Payload sample: ${payload.first}");
        final response = await _apiService.syncGestures(payload);

        print(
          "📤 [Sync] Push Response: success=${response.success}, msg=${response.message}",
        );
        if (response.data != null) {
          print("📤 [Sync] Response data: ${response.data}");
        }

        if (response.success && response.data != null) {
          // Server might return IDs. For V1 simple sync, we just mark as synced.
          // Ideally we parse response to get server IDs and map them back to UUIDs.
          for (var g in pending) {
            // We assume success means they are saved.
            // Ideally we update server_id if API returns it.
            // For now, mark as synced.
            await _db.markAsSynced(g.uuid);
          }
          print("✅ [Sync] Push Complete.");
        } else {
          print("⚠️ [Sync] Push Failed: ${response.message}");
        }
      }

      // 2. PULL: Get latest from server
      // For V1, we just get ALL and upsert. inefficient but safe.
      print("📥 [Sync] Pulling latest data...");
      final pullResponse = await _apiService.getGestures();

      // DEBUG: Full API response
      print(
        "📥 [Sync] API Response: success=${pullResponse.success}, msg=${pullResponse.message}",
      );
      print("📥 [Sync] API Data: ${pullResponse.data}");

      if (pullResponse.success && pullResponse.data != null) {
        print(
          "🔍 [Sync] Response Data Keys: ${pullResponse.data!.keys.toList()}",
        );
        // Check if gestures key exists
        if (!pullResponse.data!.containsKey('gestures')) {
          print("❌ [Sync] 'gestures' key MISSING in response data!");
          // Try to see if it's nested differently or just print raw data summary
          print("   -> Data: ${pullResponse.data}");
        }
        final serverList = pullResponse.data!['gestures'] as List;
        print("📥 [Sync] Server returned ${serverList.length} gestures");
        await _db.upsertFromServer(serverList);
        print("✅ [Sync] Pull Complete (${serverList.length} items).");
      } else {
        print("❌ [Sync] Pull FAILED or data is null: ${pullResponse.message}");
      }

      // 3. RELOAD UI
      final freshGestures = await _db.getAllGestures();
      state = state.copyWith(gestures: freshGestures, isSyncing: false);
      OverlayService.updateGestures(freshGestures);
    } catch (e) {
      // If server is down, this is expected in offline mode.
      print("⚠️ [Sync] Server unreachable (Offline Mode): ${e.toString()}");
      print("❌ [Sync Error Details] $e");
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Save a new gesture (Offline First)
  Future<bool> saveGesture(GestureModel gesture) async {
    // Validation: Max 4 Favorites
    if (gesture.isFavorite) {
      final currentFavorites = state.gestures.where((g) => g.isFavorite).length;
      // If we are updating, ignore self? This is SAVE (Insert)?
      if (currentFavorites >= 4) {
        state = state.copyWith(
          isLoading: false,
          error: "Maximum 4 Quick Panel shortcuts allowed",
        );
        return false;
      }
    }

    // state = state.copyWith(isLoading: true);
    // Don't show loading for offline save, it's instant.

    try {
      print(
        "💾 [Offline] Saving Gesture: ${gesture.name} (UUID: ${gesture.uuid}) Points: ${gesture.points.length}",
      );

      // Insert to DB (needs_sync=1 default)
      await _db.insertGesture(gesture);

      // Reload UI in background (don't block success)
      _loadGestures().catchError((e) {
        print("⚠️ UI Reload warning: $e");
      });

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Database Write Failed: $e',
      );
      return false;
    }
  }

  /// Delete a gesture (Soft Delete with Server Sync)
  Future<bool> deleteGesture(String uuid) async {
    try {
      // 1. Soft delete locally (marks is_deleted=1, needs_sync=1)
      await _db.softDeleteGesture(uuid);
      print("🗑️ [Offline] Soft deleted $uuid locally");

      // 3. Update UI Local State immediately (Optimistic)
      final updatedGestures = state.gestures
          .where((g) => g.uuid != uuid)
          .toList();
      state = state.copyWith(gestures: updatedGestures);

      // Update Native Overlay (Fire and Forget)
      OverlayService.updateGestures(updatedGestures);

      // 4. Sync delete to server in background
      _syncDeletedGestures();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Database Delete Failed: $e',
      );
      return false;
    }
  }

  /// Background sync for deleted gestures
  Future<void> _syncDeletedGestures() async {
    try {
      final deletedGestures = await _db.getDeletedGestures();
      if (deletedGestures.isEmpty) return;

      print(
        "🔄 [Sync] Found ${deletedGestures.length} deleted gestures to sync",
      );

      for (var gesture in deletedGestures) {
        print(
          "🔍 [Sync] Processing deleted: ${gesture.name}, id=${gesture.id}",
        );
        if (gesture.id != null) {
          // Has server ID - need to delete from server
          try {
            print("📤 [Sync] DELETE /gestures/${gesture.id}...");
            final response = await _apiService.dio.delete(
              '/gestures/${gesture.id}',
            );
            print("📥 [Sync] Response code: ${response.statusCode}");
            if (response.statusCode == 200) {
              // Server confirmed deletion - permanently remove locally
              await _db.permanentlyDelete(gesture.uuid);
              print("✅ [Sync] Deleted ${gesture.name} from server");
            }
          } catch (e) {
            // If 404 Not Found, it's already deleted on server. Treat as success.
            // Using dynamic for safer access if DioException not locally visible
            final is404 =
                e.toString().contains("404") ||
                ((e as dynamic).response?.statusCode == 404);

            if (is404) {
              print(
                "⚠️ [Sync] Server returned 404 (Already Deleted). Cleaning up locally.",
              );
              await _db.permanentlyDelete(gesture.uuid);
            } else {
              // Server unreachable/error - will retry on next sync
              print("⚠️ [Sync] Failed to delete ${gesture.name}: $e");
            }
          }
        } else {
          // Never synced to server - just delete locally
          await _db.permanentlyDelete(gesture.uuid);
          print(
            "🗑️ [Sync] Permanently deleted unsynced gesture: ${gesture.name}",
          );
        }
      }
    } catch (e) {
      print("❌ [Sync] Error syncing deleted gestures: $e");
    }
  }

  /// Update a gesture
  Future<bool> updateGesture(String uuid, GestureModel updatedGesture) async {
    // Validation: Max 4 Favorites
    if (updatedGesture.isFavorite) {
      // Calculate active favorites, EXCLUDING the one being updated (to allow self-updates)
      final activeFavorites = state.gestures
          .where((g) => g.isFavorite && g.uuid != uuid)
          .length;

      if (activeFavorites >= 4) {
        state = state.copyWith(
          isLoading: false,
          error: "Maximum 4 Quick Panel shortcuts allowed",
        );
        return false;
      }
    }

    try {
      await _db.updateGesture(updatedGesture);
      print("✏️ [Offline] Updated $uuid locally");

      _loadGestures().catchError((e) {
        print("⚠️ UI Reload warning: $e");
      });

      // Trigger background sync to push update to server
      _syncInBackground();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Database Update Failed: $e');
      return false;
    }
  }

  /// Add gesture locally (Legacy/Helper)
  void addGestureLocally(GestureModel gesture) {
    // This is now redundant as we saveDB -> load.
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Gesture provider
/// NOTE: We watch authProvider to trigger rebuild when auth state changes.
/// This ensures sync runs AFTER user is authenticated.
final gestureProvider = StateNotifierProvider<GestureNotifier, GestureState>((
  ref,
) {
  // Watch authProvider - when it changes (e.g., token loaded), this provider rebuilds
  final authState = ref.watch(authProvider);
  print("🔁 [GestureProvider] Rebuilding. Auth: ${authState.isAuthenticated}");
  return GestureNotifier(ref.watch(apiServiceProvider), ref);
});
