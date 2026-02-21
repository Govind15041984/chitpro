import 'chit_schedule.dart';

enum ChitLifecycleStatus { DRAFT, CONFIGURED, ACTIVE, RUNNING, CLOSED }

class ChitDraft {
  final String? id;
  final String groupName;
  final int chitAmount;
  final int totalMonths;
  final int? totalSlots;
  final ChitLifecycleStatus status;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic> ruleSettings;

  ChitDraft({
    this.id,
    required this.groupName,
    required this.chitAmount,
    required this.totalMonths,
    this.totalSlots,
    required this.status,
    this.members = const [],
    this.ruleSettings = const {},
  });

  ChitDraft copyWith({
    ChitLifecycleStatus? status,
    List<Map<String, dynamic>>? members,
    Map<String, dynamic>? ruleSettings,
  }) {
    return ChitDraft(
      id: id,
      groupName: groupName,
      chitAmount: chitAmount,
      totalMonths: totalMonths,
      totalSlots: totalSlots,
      status: status ?? this.status,
      members: members ?? this.members,
      ruleSettings: ruleSettings ?? this.ruleSettings,
    );
  }
}

