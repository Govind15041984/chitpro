import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chit_create_api.dart';
import '../data/auction_api.dart';
import 'auction_round_state.dart';

class AuctionRoundController extends StateNotifier<AuctionRoundState> {
  AuctionRoundController(String chitGroupId)
      : super(AuctionRoundState.initial(chitGroupId));

  Future<void> loadLiveRound() async {
    try {
      state = state.copyWith(phase: AuctionPhase.opening);

      final live = await AuctionApi.getLiveAuction(state.chitGroupId);

      if (live == null) {
        state = state.copyWith(phase: AuctionPhase.idle);
        return;
      }

      state = state.copyWith(
        phase: AuctionPhase.open,
        liveRoundId: live["id"],
        currentMonth: live["month_no"],
        prizeAmount: live["payout_amount"],
        dividendPerMember: live["dividend_per_member"],
        reservePool: live["reserve_amount"],
      );
    } catch (e) {
      state = state.copyWith(phase: AuctionPhase.error, error: e.toString());
    }
  }

  Future<void> openRound() async {
    try {
      state = state.copyWith(phase: AuctionPhase.opening);

      final res = await AuctionApi.openAuction(
        chitGroupId: state.chitGroupId,
        monthNo: state.currentMonth,
      );

      state = state.copyWith(
        phase: AuctionPhase.open,
        liveRoundId: res["id"],
      );
    } catch (e) {
      state = state.copyWith(phase: AuctionPhase.error, error: e.toString());
    }
  }

  Future<void> closeRound({
    required String winningMemberId,
    int? bidAmount,
  }) async {
    try {
      state = state.copyWith(phase: AuctionPhase.closing);

      final res = await AuctionApi.closeAuction(
        auctionRoundId: state.liveRoundId!,
        winningMemberId: winningMemberId,
        winningBidAmount: bidAmount,
      );

      state = state.copyWith(
        phase: AuctionPhase.closed,
        prizeAmount: res["payout_amount"],
        dividendPerMember: res["dividend_per_member"],
        reservePool: res["reserve_amount"],
        currentMonth: state.currentMonth + 1,
        liveRoundId: null,
      );
    } catch (e) {
      state = state.copyWith(phase: AuctionPhase.error, error: e.toString());
    }
  }

  void setChitType({
    required bool kulukal,
    required bool baseRule,
    int? baseAmount,
  }) {
    state = state.copyWith(
      isKulukal: kulukal,
      hasBaseAmountRule: baseRule,
      baseAmount: baseAmount,
    );
  }
}
