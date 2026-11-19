enum RecoveryState {
  prepared,
  safetyCopyCreated,
  safetyCopyVerified,
  candidateCreated,
  candidateVerified,
  switchStarted,
  previousDatabasePreserved,
  candidatePlaced,
  candidateReopened,
  completed,
  rollbackStarted,
  rollbackCompleted,
  recoveryFailed,
}

extension RecoveryStateName on RecoveryState {
  String get wireName {
    switch (this) {
      case RecoveryState.prepared:
        return 'prepared';
      case RecoveryState.safetyCopyCreated:
        return 'safety_copy_created';
      case RecoveryState.safetyCopyVerified:
        return 'safety_copy_verified';
      case RecoveryState.candidateCreated:
        return 'candidate_created';
      case RecoveryState.candidateVerified:
        return 'candidate_verified';
      case RecoveryState.switchStarted:
        return 'switch_started';
      case RecoveryState.previousDatabasePreserved:
        return 'previous_database_preserved';
      case RecoveryState.candidatePlaced:
        return 'candidate_placed';
      case RecoveryState.candidateReopened:
        return 'candidate_reopened';
      case RecoveryState.completed:
        return 'completed';
      case RecoveryState.rollbackStarted:
        return 'rollback_started';
      case RecoveryState.rollbackCompleted:
        return 'rollback_completed';
      case RecoveryState.recoveryFailed:
        return 'recovery_failed';
    }
  }

  static RecoveryState? parse(String value) {
    for (final state in RecoveryState.values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

class RecoveryStateMachine {
  const RecoveryStateMachine._();

  static const Map<RecoveryState, Set<RecoveryState>> allowedTransitions = {
    RecoveryState.prepared: {
      RecoveryState.safetyCopyCreated,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.safetyCopyCreated: {
      RecoveryState.safetyCopyVerified,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.safetyCopyVerified: {
      RecoveryState.candidateCreated,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.candidateCreated: {
      RecoveryState.candidateVerified,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.candidateVerified: {
      RecoveryState.switchStarted,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.switchStarted: {
      RecoveryState.previousDatabasePreserved,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.previousDatabasePreserved: {
      RecoveryState.candidatePlaced,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.candidatePlaced: {
      RecoveryState.candidateReopened,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.candidateReopened: {
      RecoveryState.completed,
      RecoveryState.rollbackStarted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.rollbackStarted: {
      RecoveryState.rollbackCompleted,
      RecoveryState.recoveryFailed,
    },
    RecoveryState.completed: {},
    RecoveryState.rollbackCompleted: {},
    RecoveryState.recoveryFailed: {},
  };

  static bool isTerminal(RecoveryState state) =>
      state == RecoveryState.completed ||
      state == RecoveryState.rollbackCompleted ||
      state == RecoveryState.recoveryFailed;

  static void validateTransition(RecoveryState current, RecoveryState next) {
    if (current == next) return;
    if (!allowedTransitions[current]!.contains(next)) {
      throw RecoveryStateTransitionException(
        'Invalid recovery transition: ${current.wireName} -> ${next.wireName}',
      );
    }
  }
}

class RecoveryStateTransitionException implements Exception {
  const RecoveryStateTransitionException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryStateTransitionException: $message';
}
