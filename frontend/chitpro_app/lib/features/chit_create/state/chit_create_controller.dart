import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../models/chit_draft.dart';
import '../models/member_slot.dart';
import '../models/chit_schedule.dart';
import '../data/chit_create_api.dart';
import '../data/chit_schedule_api.dart';
import 'chit_create_state.dart';

class ChitStateException implements Exception {
  final String message;
  ChitStateException(this.message);
}

class ChitCreateController extends ChangeNotifier {
  ChitDraft? _draft;
  ChitDraft get draft => _draft!;

  bool _loading = false;
  bool get isLoading => _loading;

  ChitCreateStep _uiStep = ChitCreateStep.draft;
  ChitCreateStep get uiStep => _uiStep;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  // -------------------------
  // STEP 1: DRAFT
  // -------------------------
  Future<void> createDraft({
    required String groupName,
    required int chitAmount,
    required int totalMembers,
    required int durationMonths,
  }) async {
    _setLoading(true);
    try {
      final res = await ChitCreateApi.createDraft(
        groupName: groupName,
        chitAmount: chitAmount,
        totalMembers: totalMembers,
        durationMonths: durationMonths,
      );

      _draft = ChitDraft(
        id: res["id"],
        groupName: groupName,
        chitAmount: chitAmount,
        totalMonths: durationMonths,
        totalSlots: totalMembers,
        status: ChitLifecycleStatus.DRAFT,
      );

      _uiStep = ChitCreateStep.configured;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------
  // STEP 2: CONFIGURE RULES
  // -------------------------
  Future<void> configureRules(Map<String, dynamic> ruleSettings) async {
    _ensureDraftExists();

    _setLoading(true);
    try {
      await ChitCreateApi.configureChit(_draft!.id!, ruleSettings);

      _draft = _draft!.copyWith(
        ruleSettings: ruleSettings,
        status: ChitLifecycleStatus.CONFIGURED,
      );

      // ✅ MOVE FLOW FORWARD (finish wizard)
      _uiStep = ChitCreateStep.configured;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }


  // -------------------------
  // HELPERS
  // -------------------------
  void _ensureDraftExists() {
    if (_draft == null) {
      throw ChitStateException("Chit draft not initialized");
    }
  }

  void reset() {
    _draft = null;
    _uiStep = ChitCreateStep.draft;
    notifyListeners();
  }

  Future<List<dynamic>> previewRules(Map<String, dynamic> ruleSettings) async {
    _ensureDraftExists();
    return await ChitCreateApi.previewRules(_draft!.id!, ruleSettings);
  }
}


