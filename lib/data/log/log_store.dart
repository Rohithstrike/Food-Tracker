// Storage for logged food entries.
//
// The rest of the app talks to LogStore only. A persistent implementation
// (SQLite, planned for Batch 5) can replace InMemoryLogStore without any
// change to the controller or the screens.

import '../../domain/log/log_entry.dart';

abstract interface class LogStore {
  /// Entries saved for one local calendar date, in no particular order.
  Future<List<LogEntry>> entriesFor(LocalDate date);

  /// Saves a new entry. Throws [ArgumentError] if the id is already used.
  Future<void> add(LogEntry entry);

  /// Removes an entry. Removing an unknown id does nothing.
  Future<void> remove(String id);
}

/// Keeps entries in memory only. Everything is lost when the app closes.
final class InMemoryLogStore implements LogStore {
  final Map<String, LogEntry> _entries = <String, LogEntry>{};

  @override
  Future<List<LogEntry>> entriesFor(LocalDate date) async =>
      List<LogEntry>.unmodifiable(
        _entries.values.where((LogEntry entry) => entry.date == date),
      );

  @override
  Future<void> add(LogEntry entry) async {
    if (_entries.containsKey(entry.id)) {
      throw ArgumentError('Duplicate entry id: ${entry.id}');
    }
    _entries[entry.id] = entry;
  }

  @override
  Future<void> remove(String id) async {
    _entries.remove(id);
  }
}
