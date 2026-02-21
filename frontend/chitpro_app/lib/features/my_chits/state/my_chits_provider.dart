import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/my_chits_api.dart';
import '../models/chit_card_vm.dart';
import 'my_chits_state.dart';

final myChitsProvider =
StateNotifierProvider<MyChitsController, MyChitsState>((ref) {
  return MyChitsController()..load();
});

class MyChitsController extends StateNotifier<MyChitsState> {
  MyChitsController() : super(MyChitsState.initial());

  Future<void> load() async {
    state = state.copyWith(loading: true);

    final data = await MyChitsApi.fetchChits();

    final cards = data.map<ChitCardVM>((g) {
      final status = g["lifecycle_status"];

      return ChitCardVM(
        id: g["id"],
        groupName: g["group_name"],
        chitAmount: g["chit_amount"],
        durationMonths: g["duration_months"],
        lifecycleStatus: status,

        // TEMP placeholders (safe)
        currentMonth: 0,
        nextAuctionText: "As scheduled",
        nextDueText: "—",
      );
    }).toList();

    state = state.copyWith(
      loading: false,
      active: cards.where((c) => c.lifecycleStatus != "CLOSED").toList(),
      closed: cards.where((c) => c.lifecycleStatus == "CLOSED").toList(),
    );
  }
}
