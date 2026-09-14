import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Admin-only account facts that live on the Auth user rather than in
/// Firestore, fetched through the adminGetAccountStatus callable.
///
/// Results are cached for the session and published through [emailVerified],
/// so every list in the admin panel can ask for the uids it is showing and
/// rebuild once, without refetching on each scroll or keystroke.
class AccountAdminRepository {
  final FirebaseFunctions _functions;

  AccountAdminRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// uid → whether that account has verified its email. A uid is absent
  /// until fetched, or when it has no Auth user at all.
  final ValueNotifier<Map<String, bool>> emailVerified = ValueNotifier({});

  final Set<String> _requested = {};

  /// Fetches status for any of [uids] not already known or in flight.
  /// Failures are swallowed: a missing badge is better than a broken list, and
  /// the uids become eligible for another try.
  Future<void> ensureStatus(Iterable<String> uids) async {
    final missing = uids.where(_requested.add).toList();
    for (var i = 0; i < missing.length; i += 100) {
      final chunk = missing.sublist(i, (i + 100).clamp(0, missing.length));
      try {
        final result = await _functions
            .httpsCallable('adminGetAccountStatus')
            .call<Map<String, dynamic>>({'uids': chunk});
        final status = Map<String, dynamic>.from(result.data['status'] as Map);
        emailVerified.value = {
          ...emailVerified.value,
          for (final e in status.entries)
            e.key: (e.value as Map)['emailVerified'] == true,
        };
      } catch (_) {
        _requested.removeAll(chunk);
      }
    }
  }

  /// Frees every phone number [uid] holds. Returns the numbers released —
  /// empty when the account held none.
  Future<List<String>> releasePhone(String uid) async {
    final result = await _functions
        .httpsCallable('adminReleasePhone')
        .call<Map<String, dynamic>>({'uid': uid});
    return List<String>.from(result.data['released'] as List);
  }
}
