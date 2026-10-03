import 'package:equatable/equatable.dart';

/// A learner-chosen time of day for the one local daily reminder
/// (FR-048a). Deliberately not `TimeOfDay` — that is a Material widget
/// type, and `contracts/repositories.md`'s domain layer stays pure Dart.
class ReminderTime extends Equatable {
  const ReminderTime({required this.hour, required this.minute});

  /// FR-048a's default: the morning.
  static const ReminderTime defaultTime = ReminderTime(hour: 9, minute: 0);

  final int hour;
  final int minute;

  @override
  List<Object?> get props => <Object?>[hour, minute];
}
