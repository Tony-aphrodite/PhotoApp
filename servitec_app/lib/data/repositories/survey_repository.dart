import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

/// The user-test survey link, kept in `configuracion/encuesta` so the admin
/// can set or change it from the panel without shipping a new APK.
///
/// The link is a Google Forms *pre-filled* link in which the form owner typed
/// the placeholders CODIGO, ROL and VERSION into the three hidden-ish short
/// answer fields. [buildUri] swaps those placeholders for the tester's code,
/// role and app version — never an email or phone number.
class SurveyRepository {
  final FirebaseFirestore _firestore;

  SurveyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(AppConstants.configCollection).doc('encuesta');

  /// The configured link, or null while none is set (the button stays hidden).
  Stream<String?> watchLink() => _doc.snapshots().map((snap) {
        final url = (snap.data()?['url'] as String?)?.trim();
        return (url == null || url.isEmpty) ? null : url;
      });

  /// Admin only (firestore.rules: configuracion is admin-write). An empty
  /// string removes the link and hides the button.
  Future<void> saveLink(String url) => _doc.set({
        'url': url.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static const placeholders = ['CODIGO', 'ROL', 'VERSION'];

  /// Whether [url] looks like a pre-filled Google Forms link carrying all
  /// three placeholders.
  static bool isValidTemplate(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.host.contains('google.com')) return false;
    final values = uri.queryParametersAll.values.expand((v) => v).toSet();
    return placeholders.every(values.contains);
  }

  static Uri buildUri(
    String template, {
    required String codigo,
    required String rol,
    required String version,
  }) {
    final uri = Uri.parse(template.trim());
    final replaced = <String, List<String>>{
      for (final e in uri.queryParametersAll.entries)
        e.key: e.value
            .map((v) => switch (v) {
                  'CODIGO' => codigo,
                  'ROL' => rol,
                  'VERSION' => version,
                  _ => v,
                })
            .toList(),
    };
    return uri.replace(queryParameters: replaced);
  }
}
