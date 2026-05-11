import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';
import 'package:gesture_app/features/bulk_dialer/services/bulk_api_service.dart';
import 'package:gesture_app/features/bulk_dialer/services/excel_service.dart';
import 'package:gesture_app/features/bulk_dialer/services/ocr_service.dart';
import 'package:gesture_app/core/services/native_direct_caller.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:gesture_app/core/database/database_helper.dart'; // NEW: Local Cache

final bulkDialerProvider =
    StateNotifierProvider<BulkDialerController, BulkDialerState>((ref) {
      return BulkDialerController();
    });

class BulkDialerState {
  final bool isLoading;
  final bool isSyncing; // NEW: Background sync indicator
  final DialerSessionModel? currentSession;
  final List<BulkNumberModel> numbers;
  final String? error;
  final bool isOfflineMode; // NEW: Indicate offline data

  BulkDialerState({
    this.isLoading = false,
    this.isSyncing = false,
    this.currentSession,
    this.numbers = const [],
    this.error,
    this.isOfflineMode = false,
  });

  BulkDialerState copyWith({
    bool? isLoading,
    bool? isSyncing,
    DialerSessionModel? currentSession,
    List<BulkNumberModel>? numbers,
    String? error,
    bool? isOfflineMode,
  }) {
    return BulkDialerState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      currentSession: currentSession ?? this.currentSession,
      numbers: numbers ?? this.numbers,
      error: error, // Can set null
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
    );
  }
}

class BulkDialerController extends StateNotifier<BulkDialerState> {
  final _api = BulkApiService(); // Replaced _db
  final _db = DatabaseHelper(); // NEW: Local DB
  final _ocr = OcrService();
  final _excel = ExcelService();

  BulkDialerController() : super(BulkDialerState()) {
    // Listen for Auto-Save from Overlay
    OverlayService.onNoteSavedCallback = (text) {
      if (_activeCallNumberId != null) {
        final target = state.numbers.firstWhere(
          (n) => n.id == _activeCallNumberId,
          orElse: () => BulkNumberModel(id: -1, sessionId: -1, phoneNumber: ''),
        );
        if (target.id != -1) {
          print("💾 Auto-Saving Note for #${target.id}: $text");
          saveNote(target, text);
          _activeCallNumberId = null; // Reset
        }
      }
    };
  }

  int? _activeCallNumberId;

  /// Start a new session or load latest
  /// UPDATED: Load from local cache first, then sync in BACKGROUND (non-blocking)
  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🎮 CONTROLLER: loadSession started');

      // STEP 1: Try to load from local DB FIRST (Instant)
      final cachedSession = await _db.getLastActiveBulkSession();
      if (cachedSession != null) {
        print('💾 CONTROLLER: Found cached session: ${cachedSession.name}');
        final cachedNumbers = await _db.getBulkNumbers(cachedSession.id!);
        state = state.copyWith(
          isLoading: false, // UI is ready!
          currentSession: cachedSession,
          numbers: cachedNumbers,
          isOfflineMode: true, // Mark as potentially stale
          isSyncing: true, // Show sync indicator
        );

        // STEP 2: Sync from API in BACKGROUND (Fire-and-forget, don't await!)
        _syncFromApi(); // No await - runs in background
      } else {
        // No cache - must wait for API
        print('💾 CONTROLLER: No cached session, fetching from API...');
        state = state.copyWith(isSyncing: true);
        await _syncFromApi(); // Await only when no cache
      }
    } catch (e) {
      print('❌ CONTROLLER ERROR: $e');
      // If we have cached data, don't show error (just keep offline mode)
      if (state.currentSession == null) {
        state = state.copyWith(
          isLoading: false,
          isSyncing: false,
          error: _getErrorMessage(e),
        );
      } else {
        state = state.copyWith(isLoading: false, isSyncing: false);
      }
    }
  }

  /// NEW: Background sync from API
  Future<void> _syncFromApi() async {
    try {
      final sessions = await _api.getSessions();
      if (sessions.isNotEmpty) {
        print('🎮 CONTROLLER: API returned ${sessions.length} sessions');
        final latest = sessions.first;
        final nums = await _api.getNumbers(latest.id!);

        // Save to local DB in PARALLEL
        await Future.wait([
          _db.upsertBulkSession(latest, isActive: true),
          _db.upsertBulkNumbers(latest.id!, nums),
        ]);

        state = state.copyWith(
          isLoading: false,
          isSyncing: false,
          currentSession: latest,
          numbers: nums,
          isOfflineMode: false,
          error: null,
        );
      } else if (state.currentSession == null) {
        // No remote sessions and no local cache -> create new
        print('🎮 CONTROLLER: No sessions found. Creating new.');
        await createNewSession();
      } else {
        state = state.copyWith(isSyncing: false, isOfflineMode: false);
      }
    } catch (e) {
      print('⚠️ CONTROLLER: Background sync failed: $e');
      state = state.copyWith(isSyncing: false);
      // Don't set error if we already have cached data
    }
  }

  Future<void> createNewSession() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final name =
          "Session ${DateTime.now().toLocal().toString().split('.')[0]}";

      final newSession = await _api.createSession(name);

      // NEW: Cache to local DB
      await _db.upsertBulkSession(newSession, isActive: true);

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        currentSession: newSession,
        numbers: [],
        isOfflineMode: false,
      );
    } catch (e) {
      print("⚠️ Create Session Failed: $e");

      // Fallback: Create Local Offline Session
      final localSession = DialerSessionModel(
        id: -DateTime.now().millisecondsSinceEpoch, // Negative ID for local
        name:
            "Offline Session ${DateTime.now().toLocal().toString().split('.')[0]}",
        createdAt: DateTime.now().toIso8601String(),
      );

      await _db.upsertBulkSession(localSession, isActive: true);

      state = state.copyWith(
        isLoading: false,
        isSyncing: false,
        currentSession: localSession,
        numbers: [], // Clear numbers for new session
        isOfflineMode: true,
        error: "Offline Session Created (Connection Failed)",
      );
    }
  }

  // --- Import Actions ---

  Future<void> importFromText(String text) async {
    if (state.currentSession == null) return;
    state = state.copyWith(isLoading: true);

    // Split by newlines and clean
    final rawNumbers = text.split(RegExp(r'\r?\n'));
    await _processAndAddNumbers(rawNumbers);
  }

  Future<void> importFromImage(File image) async {
    if (state.currentSession == null) return;
    state = state.copyWith(isLoading: true);

    try {
      final extracted = await _ocr.extractPhoneNumbers(image);
      await _processAndAddNumbers(extracted);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  Future<void> importFromExcel(File file) async {
    if (state.currentSession == null) return;
    state = state.copyWith(isLoading: true);

    try {
      final extracted = await _excel.importNumbers(file);
      await _processAndAddNumbers(extracted);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  Future<void> _processAndAddNumbers(List<String> rawNumbers) async {
    int sessionId = state.currentSession!.id!;
    List<BulkNumberModel> toAdd = [];

    for (var raw in rawNumbers) {
      String clean = raw.trim(); // Replace with better cleaning if needed
      if (clean.length > 2) {
        // Basic checking
        toAdd.add(BulkNumberModel(sessionId: sessionId, phoneNumber: clean));
      }
    }

    if (toAdd.isNotEmpty) {
      // 1. Optimistic UI: Save to Local DB with Temp IDs (Negative)
      final tempNumbers = toAdd.map((n) {
        // Generate pseudo-unique negative ID
        return n.copyWith(
          id: -DateTime.now().microsecondsSinceEpoch - toAdd.indexOf(n),
        );
      }).toList();

      try {
        await _db.upsertBulkNumbers(sessionId, tempNumbers);

        // Update UI immediately (Append temps)
        state = state.copyWith(
          isLoading: false,
          numbers: [...state.numbers, ...tempNumbers],
          error: null,
        );

        // 2. Try Sync to API (Background-ish)
        try {
          // Remove IDs before sending to server (Server generates IDs)
          final payload = tempNumbers
              .map((n) => n.copyWith(id: null))
              .toList(); // id must be null for API
          await _api.addNumbers(sessionId, payload);

          // 3. If Success: Reload from Server & Cleanup Temps
          final serverNums = await _api.getNumbers(sessionId);

          // Cleanup Temps (Delete negative IDs for this session)
          final db = await _db.database;
          await db.delete(
            'bulk_numbers',
            where: 'session_id = ? AND id < 0',
            whereArgs: [sessionId],
          );

          // Save Server Data
          await _db.upsertBulkNumbers(sessionId, serverNums);

          // Update State with real data
          state = state.copyWith(numbers: serverNums, error: null);
        } catch (e) {
          print("⚠️ Sync Failed, keeping local data: $e");
          // Update state to show warning but KEEP numbers
          state = state.copyWith(
            error: "Saved locally. Sync failed (Offline).",
            isOfflineMode: true,
          );
        }
      } catch (e) {
        state = state.copyWith(isLoading: false, error: "Failed to save: $e");
      }
    } else {
      state = state.copyWith(
        isLoading: false,
        error: "No valid numbers found (Minimum 3 digits required)",
      );
    }
  }

  // --- Call Actions ---

  Future<void> callNumber(BulkNumberModel number) async {
    _activeCallNumberId = number.id; // Track for Auto-Save
    try {
      // 1. Show Note Bubble
      final noteText = number.notes;
      // Fix: Removed unnecessary null aware since we first check if it's not null and not empty
      final displayName = (number.name != null && number.name!.isNotEmpty)
          ? number.name!.toUpperCase()
          : number.phoneNumber;
      final statusText = "CALLING $displayName";

      try {
        await OverlayService.showNote(noteText, status: statusText);
      } catch (e) {
        print("Overlay Error $e");
      }

      // 2. Direct Call (Native MethodChannel)
      final bool res = await NativeDirectCaller.callNumber(number.phoneNumber);

      if (res == true) {
        // Mark as called
        final updated = number.copyWith(
          status: CallStatus.called,
          lastCalledAt: DateTime.now(),
        );

        await _api.updateNumber(updated); // Update API

        // Update State
        state = state.copyWith(
          numbers: state.numbers
              .map((n) => n.id == number.id ? updated : n)
              .toList(),
        );
      } else {
        state = state.copyWith(error: "Could not launch direct call");
      }
    } catch (e) {
      state = state.copyWith(error: _getErrorMessage(e));
    }
  }

  // --- Note Actions ---

  Future<void> saveNote(BulkNumberModel number, String note) async {
    try {
      final updated = number.copyWith(notes: note);
      await _api.updateNumber(updated);

      state = state.copyWith(
        numbers: state.numbers
            .map((n) => n.id == number.id ? updated : n)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: _getErrorMessage(e));
    }
  }

  Future<void> editNumber(
    BulkNumberModel number,
    String newNumber,
    String? newName,
  ) async {
    try {
      final updated = number.copyWith(phoneNumber: newNumber, name: newName);
      await _api.updateNumber(updated);

      state = state.copyWith(
        numbers: state.numbers
            .map((n) => n.id == number.id ? updated : n)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: _getErrorMessage(e));
    }
  }

  // --- Export ---

  Future<void> exportReport() async {
    if (state.currentSession == null) return;

    try {
      await _excel.exportSession(state.currentSession!.name, state.numbers);
    } catch (e) {
      state = state.copyWith(error: "Export Failed: $e");
    }
  }

  Future<void> finishAndClearSession() async {
    if (state.currentSession == null) return;
    state = state.copyWith(isLoading: true);

    try {
      // 1. Export
      await _excel.exportSession(state.currentSession!.name, state.numbers);

      // 2. Delete from DB
      await _api.deleteSession(state.currentSession!.id!);

      // 3. Clear State (or create new empty session)
      await createNewSession();

      // Note: createNewSession sets isLoading=false
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  // --- Status Toggle ---
  Future<void> toggleStatus(BulkNumberModel number) async {
    // Cycle: Pending -> Called -> Skipped -> Pending
    CallStatus next;
    switch (number.status) {
      case CallStatus.pending:
        next = CallStatus.called;
        break;
      case CallStatus.called:
        next = CallStatus.skipped;
        break;
      case CallStatus.skipped:
        next = CallStatus.pending;
        break;
    }

    final updated = number.copyWith(status: next);
    await _api.updateNumber(updated);

    state = state.copyWith(
      numbers: state.numbers
          .map((n) => n.id == number.id ? updated : n)
          .toList(),
    );
  }

  // --- Error Helper ---
  // UPDATED: Differentiate Timeout vs No Internet
  String _getErrorMessage(dynamic e) {
    final str = e.toString().toLowerCase();

    // TIMEOUT (Slow connection, server might just be slow)
    if (str.contains('connection timeout') ||
        str.contains('sendtimeout') ||
        str.contains('receivetimeout')) {
      return "⏳ Connection is slow. Please wait or try again.";
    }

    // NO INTERNET (True network failure)
    if (str.contains('socketexception') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('no internet connection')) {
      return "📶 No internet connection. Please check your network.";
    }

    // AUTH ERRORS
    if (str.contains('401') || str.contains('unauthorized')) {
      return "🔑 Session Expired. Please Re-Login.";
    }

    // Return clean message if possible, else simplified generic
    return e.toString().contains("Exception:")
        ? e.toString().split("Exception:").last.trim()
        : "Something went wrong. Please try again.";
  }
}
