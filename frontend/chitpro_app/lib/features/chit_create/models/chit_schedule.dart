enum ChitScheduleType {
  fixedDate,
  nthWeekday,
  interval,
  custom,
}

class ChitSchedule {
  final ChitScheduleType type;
  final Map<String, dynamic> rule;
  final DateTime startDate;
  final DateTime? nextRun;

  ChitSchedule({
    required this.type,
    required this.rule,
    required this.startDate,
    this.nextRun,
  });

  Map<String, dynamic> toJson() => {
    "schedule_type": type.name.toUpperCase(),
    "rule": rule,
    "start_date": startDate.toIso8601String(),
  };
}
