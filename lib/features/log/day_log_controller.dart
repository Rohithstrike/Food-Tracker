// Today's food log, for the screens.
//
// Holds the current local day's DayLog. Entries are built by the existing
// EntryBuilder, so every number comes from the NutritionEngine. Undo
// removes one entry by id. Saving goes through LogStore, so persistent
// storage can be added later without changing any screen.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/log/log_store.dart';
import '../../domain/food/food.dart';
import '../../domain/log/day_log.dart';
import '../../domain/log/entry_builder.dart';
import '../../domain/log/log_entry.dart';

/// Returns a function that generates unique entry ids.
String Function() createEntryIdGenerator() => _EntryIdGenerator().next;

class DayLogController extends ChangeNotifier {
  DayLogController({
    required this._store,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? createEntryIdGenerator(),
       _log = DayLog(date: LocalDate.fromDateTime((clock ?? DateTime.now)()));

  final LogStore _store;
  final DateTime Function() _clock;
  final String Function() _newId;
  DayLog _log;
  int _revision = 0;
  bool _disposed = false;

  /// The current day's log.
  DayLog get log => _log;

  /// Switches to a new, empty day if the local date has changed.
  /// Returns true when the day changed.
  bool checkDate() => _ensureDate(_clock());

  /// Loads the current day's entries from the store, keeping any entries
  /// added in the meantime.
  Future<void> load() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final LocalDate date = _log.date;
      final int revision = _revision;
      final List<LogEntry> stored = await _store.entriesFor(date);
      if (_disposed || date != _log.date) {
        return;
      }
      if (revision != _revision) {
        continue;
      }
      final Map<String, LogEntry> byId = <String, LogEntry>{
        for (final LogEntry entry in stored) entry.id: entry,
        for (final LogEntry entry in _log.entries) entry.id: entry,
      };
      _log = DayLog(date: date, entries: byId.values);
      _notify();
      return;
    }
  }

  /// Builds an entry with EntryBuilder, adds it to today and saves it.
  /// If saving fails, the entry is removed again and the error is rethrown.
  Future<LogEntry> add({
    required String mealSlotId,
    required FoodPortion base,
    Food? oil,
    num oilGrams = 0,
  }) async {
    final DateTime now = _clock();
    _ensureDate(now);
    final LogEntry entry = EntryBuilder.build(
      id: _newId(),
      date: _log.date,
      mealSlotId: mealSlotId,
      timestamp: now,
      base: base,
      oil: oil,
      oilGrams: oilGrams,
    );
    _log = _log.add(entry);
    _revision++;
    _notify();
    try {
      await _store.add(entry);
    } catch (_) {
      if (_log.entryById(entry.id) != null) {
        _log = _log.remove(entry.id);
        _revision++;
        _notify();
      }
      rethrow;
    }
    return entry;
  }

  /// Removes the entry with [entryId] from today. Returns false (and changes
  /// nothing) if today has no such entry.
  Future<bool> undo(String entryId) async {
    final LogEntry? entry = _log.entryById(entryId);
    if (entry == null) {
      return false;
    }
    _log = _log.remove(entryId);
    _revision++;
    _notify();
    try {
      await _store.remove(entryId);
    } catch (_) {
      if (_log.date == entry.date && _log.entryById(entryId) == null) {
        _log = _log.add(entry);
        _revision++;
        _notify();
      }
      rethrow;
    }
    return true;
  }

  bool _ensureDate(DateTime now) {
    final LocalDate today = LocalDate.fromDateTime(now);
    if (today == _log.date) {
      return false;
    }
    _log = DayLog(date: today);
    _revision++;
    _notify();
    unawaited(load());
    return true;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final class _EntryIdGenerator {
  _EntryIdGenerator() : _random = _createRandom();

  final Random _random;
  int _counter = 0;

  String next() {
    _counter++;
    final String time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final String random = _random
        .nextInt(1 << 30)
        .toRadixString(36)
        .padLeft(6, '0');
    return 'e-$time-${_counter.toRadixString(36)}-$random';
  }

  static Random _createRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
    }
  }
}
