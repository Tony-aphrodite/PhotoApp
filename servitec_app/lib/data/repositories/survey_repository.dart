import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

/// The user-test survey links, kept in `configuracion/encuesta` so the admin
/// can set or change them from the panel without shipping a new APK.
///
/// Marketing wrote one form for clientes and one for técnicos, so each role
/// has its own link (`urlCliente`, `urlTecnico`). A single `url` from before
/// the split still works as the link for both.
///
/// A link may be a Google Forms *pre-filled* link in which the form owner
/// typed the placeholders CODIGO, ROL and VERSION into short-answer fields;
/// [buildUri] swaps them for the tester's code, role and app version — never
/// an email or phone number — so an answer can be matched to crash reports.
/// A link without placeholders opens the form as is.
class SurveyRepository {
  final FirebaseFirestore _firestore;

  SurveyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection(AppConstants.configCollection).doc('encuesta');

  static const rolCliente = 'cliente';
  static const rolTecnico = 'tecnico';

  static String _field(String rol) => rol == rolTecnico ? 'urlTecnico' : 'urlCliente';

  /// The link for [rol] out of the stored document, or null when none is set.
  static String? linkFor(Map<String, dynamic>? data, String rol) {
    String? clean(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return clean(data?[_field(rol)]) ?? clean(data?['url']);
  }

  /// The link for [rol], or null while none is set (the button stays hidden).
  Stream<String?> watchLink(String rol) =>
      _doc.snapshots().map((snap) => linkFor(snap.data(), rol));

  /// Both links as stored, for the admin dialog.
  Future<({String cliente, String tecnico})> fetchLinks() async {
    final data = (await _doc.get()).data();
    return (
      cliente: linkFor(data, rolCliente) ?? '',
      tecnico: linkFor(data, rolTecnico) ?? '',
    );
  }

  /// Admin only (firestore.rules: configuracion is admin-write). An empty
  /// string removes that role's link and hides its button.
  Future<void> saveLinks({required String cliente, required String tecnico}) =>
      _doc.set({
        'urlCliente': cliente.trim(),
        'urlTecnico': tecnico.trim(),
        // The pre-split single link would otherwise keep showing for a role
        // whose link was just cleared.
        'url': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  static const placeholders = ['CODIGO', 'ROL', 'VERSION'];

  /// Whether [url] is a Google Forms link (placeholders are optional).
  static bool isValidLink(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) return false;
    return (uri.host == 'docs.google.com' && uri.path.startsWith('/forms/')) ||
        uri.host == 'forms.gle';
  }

  /// Whether [url] carries all three placeholders, i.e. answers can be
  /// matched to a tester and an app version.
  static bool hasPlaceholders(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
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
    if (uri.queryParametersAll.isEmpty) return uri;
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
