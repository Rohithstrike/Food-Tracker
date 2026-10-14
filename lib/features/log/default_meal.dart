// Which meal a food is added to by default, based on local time.
//
//   05:00-10:29  Breakfast
//   10:30-11:59  Mid-morning
//   12:00-15:29  Lunch
//   15:30-18:59  Snacks
//   19:00-21:59  Dinner
//   22:00-04:59  Late meal
//
// Pre-workout is never chosen automatically: it depends on the user's own
// schedule. The user can always change the meal before adding food.

import '../today/today_models.dart';

const String _preWorkoutId = 'pre_workout';

String defaultMealSlotIdFor(DateTime time) {
  final DateTime local = time.toLocal();
  final int minutes = local.hour * 60 + local.minute;
  if (minutes >= 5 * 60 && minutes < 10 * 60 + 30) {
    return 'breakfast';
  }
  if (minutes >= 10 * 60 + 30 && minutes < 12 * 60) {
    return 'mid_morning';
  }
  if (minutes >= 12 * 60 && minutes < 15 * 60 + 30) {
    return 'lunch';
  }
  if (minutes >= 15 * 60 + 30 && minutes < 19 * 60) {
    return 'snacks';
  }
  if (minutes >= 19 * 60 && minutes < 22 * 60) {
    return 'dinner';
  }
  return 'late_meal';
}

/// The default meal among [slots] (the user's visible meals, in order).
/// If the time-based meal is hidden, the first visible meal other than
/// Pre-workout is used.
MealSlot defaultMealSlotFor(List<MealSlot> slots, DateTime time) {
  if (slots.isEmpty) {
    throw ArgumentError.value(slots, 'slots', 'must not be empty');
  }
  final MealSlot? preferred = mealSlotById(slots, defaultMealSlotIdFor(time));
  if (preferred != null) {
    return preferred;
  }
  for (final MealSlot slot in slots) {
    if (slot.id != _preWorkoutId) {
      return slot;
    }
  }
  return slots.first;
}

MealSlot? mealSlotById(List<MealSlot> slots, String id) {
  for (final MealSlot slot in slots) {
    if (slot.id == id) {
      return slot;
    }
  }
  return null;
}
