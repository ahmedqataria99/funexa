import 'recovery_journal.dart';
import 'recovery_state.dart';

enum StartupRecoveryDecisionType {
  noRecoveryRequired,
  recoveryPending,
  rollbackRequired,
  completedRequiresVerification,
  failClosed,
}

class StartupRecoveryDecision {
  const StartupRecoveryDecision(this.type, {this.reason});

  final StartupRecoveryDecisionType type;
  final String? reason;
}

class StartupRecoveryDecisionComponent {
  const StartupRecoveryDecisionComponent();

  StartupRecoveryDecision inspect(RecoveryJournal? journal) {
    if (journal == null) {
      return const StartupRecoveryDecision(
        StartupRecoveryDecisionType.noRecoveryRequired,
      );
    }

    switch (journal.state) {
      case RecoveryState.prepared:
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.recoveryPending,
          reason: 'A recovery operation is prepared.',
        );
      case RecoveryState.safetyCopyCreated:
        if (journal.safetyCopySha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Safety copy is missing its SHA-256 digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.recoveryPending,
        );
      case RecoveryState.safetyCopyVerified:
        if (journal.safetyCopySha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Verified safety copy has no digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.recoveryPending,
        );
      case RecoveryState.candidateCreated:
      case RecoveryState.candidateVerified:
        if (journal.candidateSha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Candidate database is missing its SHA-256 digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.recoveryPending,
        );
      case RecoveryState.switchStarted:
      case RecoveryState.previousDatabasePreserved:
      case RecoveryState.candidatePlaced:
      case RecoveryState.candidateReopened:
        if (journal.previousDatabaseSha256 == null ||
            journal.candidateSha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Post-switch rollback or candidate digest is missing.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.rollbackRequired,
          reason: 'Journal is in a post-switch state requiring verification.',
        );
      case RecoveryState.rollbackStarted:
        if (journal.previousDatabaseSha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Rollback started without a previous-database digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.rollbackRequired,
        );
      case RecoveryState.rollbackCompleted:
        if (journal.previousDatabaseSha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Rollback completed without a verified digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.completedRequiresVerification,
          reason:
              'Rollback completed; previous database requires verification.',
        );
      case RecoveryState.completed:
        if (journal.candidateSha256 == null) {
          return const StartupRecoveryDecision(
            StartupRecoveryDecisionType.failClosed,
            reason: 'Completed state has no candidate digest.',
          );
        }
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.completedRequiresVerification,
          reason:
              'Completed state requires artifact and database verification.',
        );
      case RecoveryState.recoveryFailed:
        return const StartupRecoveryDecision(
          StartupRecoveryDecisionType.failClosed,
          reason: 'Recovery failed; manual inspection is required.',
        );
    }
  }
}
