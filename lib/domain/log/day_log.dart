// One local calendar day of logged entries.
//
// DayLog is immutable: add, replace and remove return a new DayLog. This
// keeps updates predictable for the UI and for saving.
//
// Totals come from the entries' frozen snapshots via NutritionEngine.total.
// Entries in hidden or custom meal slots still count towards the day.

import '../nutrition/nutrition_engine.dart';
import 'log_entry.dart';

final class DayLog {
  DayLog({required this.date, Iterable<LogEntry> entries = const <LogEntry>[]})
    : entries = _validated(date, entries);

  final LocalDate date;

  /// Ordered by creation time, then id.
  final List<LogEntry> entries;

  /// Day totals. Unknown nutrients are counted as missing, never as zero.
  late final NutritionTotals totals = _sum(entries);

  bool get isEmpty => entries.isEmpty;

  bool get isSample => entries.any((LogEntry e) => e.isSample);

  /// Ids of every meal slot that has at least one entry.
  Set<String> get mealSlotIds =>
      entries.map((LogEntry e) => e.mealSlotId).toSet();

  List<LogEntry> entriesFor(String mealSlotId) => entries
      .where((LogEntry e) => e.mealSlotId == mealSlotId)
      .toList(growable: false);

  NutritionTotals totalsFor(String mealSlotId) => _sum(entriesFor(mealSlotId));

  LogEntry? entryById(String id) {
    for (final LogEntry entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  DayLog add(LogEntry entry) =>
      DayLog(date: date, entries: <LogEntry>[...entries, entry]);

  DayLog replace(LogEntry entry) {
    if (entryById(entry.id) == null) {
      throw ArgumentError('No entry with id ${entry.id} on $date.');
    }
    return DayLog(
      date: date,
      entries: <LogEntry>[
        for (final LogEntry existing in entries)
          existing.id == entry.id ? entry : existing,
      ],
    );
  }

  DayLog remove(String id) {
    if (entryById(id) == null) {
      throw ArgumentError('No entry with id $id on $date.');
    }
    return DayLog(
      date: date,
      entries: entries.where((LogEntry e) => e.id != id),
    );
  }

  static List<LogEntry> _validated(LocalDate date, Iterable<LogEntry> entries) {
    final List<LogEntry> list = entries.toList();
    final Set<String> ids = <String>{};
    for (final LogEntry entry in list) {
      if (entry.date != date) {
        throw ArgumentError(
          'Entry ${entry.id} is for ${entry.date}, not $date.',
        );
      }
      if (!ids.add(entry.id)) {
        throw ArgumentError('Duplicate entry id: ${entry.id}');
      }
    }
    list.sort(_byTime);
    return List<LogEntry>.unmodifiable(list);
  }

  static int _byTime(LogEntry a, LogEntry b) {
    final int byCreated = a.createdAt.compareTo(b.createdAt);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }

  static NutritionTotals _sum(Iterable<LogEntry> entries) =>
      NutritionEngine.total(
        entries.expand(
          (LogEntry e) => e.components.map((EntryComponent c) => c.nutrition),
        ),
      );
}
