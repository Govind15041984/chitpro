enum AuctionPhase {
  idle,       // No open round
  opening,    // Opening round API call
  open,       // Round is OPEN
  closing,    // Closing round API call
  closed,     // Closed, waiting for next month
  error,
}

class AuctionRoundState {
  final String chitGroupId;
  final int currentMonth;
  final bool isKulukal;
  final bool hasBaseAmountRule;

  final int? baseAmount;       // starting bid if applicable
  final int? prizeAmount;
  final int? dividendPerMember;
  final int? reservePool;

  final String? liveRoundId;
  final AuctionPhase phase;
  final String? error;

  const AuctionRoundState({
    required this.chitGroupId,
    required this.currentMonth,
    required this.isKulukal,
    required this.hasBaseAmountRule,
    this.baseAmount,
    this.prizeAmount,
    this.dividendPerMember,
    this.reservePool,
    this.liveRoundId,
    required this.phase,
    this.error,
  });

  factory AuctionRoundState.initial(String chitGroupId) {
    return AuctionRoundState(
      chitGroupId: chitGroupId,
      currentMonth: 1,
      isKulukal: false,
      hasBaseAmountRule: false,
      phase: AuctionPhase.idle,
    );
  }

  AuctionRoundState copyWith({
    int? currentMonth,
    bool? isKulukal,
    bool? hasBaseAmountRule,
    int? baseAmount,
    int? prizeAmount,
    int? dividendPerMember,
    int? reservePool,
    String? liveRoundId,
    AuctionPhase? phase,
    String? error,
  }) {
    return AuctionRoundState(
      chitGroupId: chitGroupId,
      currentMonth: currentMonth ?? this.currentMonth,
      isKulukal: isKulukal ?? this.isKulukal,
      hasBaseAmountRule: hasBaseAmountRule ?? this.hasBaseAmountRule,
      baseAmount: baseAmount ?? this.baseAmount,
      prizeAmount: prizeAmount ?? this.prizeAmount,
      dividendPerMember: dividendPerMember ?? this.dividendPerMember,
      reservePool: reservePool ?? this.reservePool,
      liveRoundId: liveRoundId ?? this.liveRoundId,
      phase: phase ?? this.phase,
      error: error,
    );
  }
}
