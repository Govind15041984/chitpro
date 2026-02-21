import '../models/chit_card_vm.dart';

class MyChitsState {
  final bool loading;
  final List<ChitCardVM> active;
  final List<ChitCardVM> closed;

  MyChitsState({
    required this.loading,
    required this.active,
    required this.closed,
  });

  factory MyChitsState.initial() {
    return MyChitsState(
      loading: true,
      active: [],
      closed: [],
    );
  }

  MyChitsState copyWith({
    bool? loading,
    List<ChitCardVM>? active,
    List<ChitCardVM>? closed,
  }) {
    return MyChitsState(
      loading: loading ?? this.loading,
      active: active ?? this.active,
      closed: closed ?? this.closed,
    );
  }
}
