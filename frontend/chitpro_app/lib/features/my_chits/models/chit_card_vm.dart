class ChitCardVM {
  final String id;
  final String groupName;
  final int chitAmount;
  final int durationMonths;
  final String lifecycleStatus;

  // Derived / placeholder (for now)
  final int currentMonth;
  final String nextAuctionText;
  final String nextDueText;

  ChitCardVM({
    required this.id,
    required this.groupName,
    required this.chitAmount,
    required this.durationMonths,
    required this.lifecycleStatus,
    required this.currentMonth,
    required this.nextAuctionText,
    required this.nextDueText,
  });
}
