import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chit_create_controller.dart';
import 'chit_create_state.dart';

final chitCreateProvider =
ChangeNotifierProvider<ChitCreateController>((ref) {
  return ChitCreateController();
});


