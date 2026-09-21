/// The pseudonymous code a user-test participant is known by.
///
/// The client asked that feedback carry no personal data — no email, no
/// phone. The code is the first six characters of the Firebase uid: random,
/// meaningless outside ServiTec, and enough for the team to find the account
/// again (the uid prefix) when cross-checking an answer with what the tester
/// actually did in the app. Crashlytics reports use the same code, so a crash
/// and a survey answer from one person line up.
class TesterIdentity {
  TesterIdentity._();

  static String codeFor(String uid) {
    final prefix = uid.length >= 6 ? uid.substring(0, 6) : uid;
    return 'T-${prefix.toUpperCase()}';
  }
}
