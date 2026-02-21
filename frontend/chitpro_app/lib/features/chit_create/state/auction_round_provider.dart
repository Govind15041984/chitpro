import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auction_round_controller.dart';
import 'auction_round_state.dart';

final auctionRoundProvider = StateNotifierProvider.family<
    AuctionRoundController, AuctionRoundState, String>((ref, chitGroupId) {
  return AuctionRoundController(chitGroupId);
});
