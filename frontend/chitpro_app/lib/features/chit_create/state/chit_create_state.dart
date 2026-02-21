// lib/features/chit_create/state/chit_create_state.dart

enum ChitCreateStep {
  draft,
  configured,
}

extension ChitCreateStepX on ChitCreateStep {
  String get label {
    switch (this) {
      case ChitCreateStep.draft:
        return "Basic Info";
      case ChitCreateStep.configured:
        return "Rules Setup";
    }
  }

  int get stepIndex {
    switch (this) {
      case ChitCreateStep.draft:
        return 0;
      case ChitCreateStep.configured:
        return 1;
    }
  }
}
