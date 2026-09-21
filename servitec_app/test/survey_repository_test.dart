import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/services/tester_identity.dart';
import 'package:servitec_app/data/repositories/survey_repository.dart';

void main() {
  const template = 'https://docs.google.com/forms/d/e/ABC/viewform'
      '?usp=pp_url&entry.111=CODIGO&entry.222=ROL&entry.333=VERSION';

  test('fills the three placeholders and keeps everything else', () {
    final uri = SurveyRepository.buildUri(template,
        codigo: 'T-4F9K2A', rol: 'cliente', version: '1.0.0+2');
    expect(uri.queryParameters['entry.111'], 'T-4F9K2A');
    expect(uri.queryParameters['entry.222'], 'cliente');
    expect(uri.queryParameters['entry.333'], '1.0.0+2');
    expect(uri.queryParameters['usp'], 'pp_url');
    expect(uri.path, '/forms/d/e/ABC/viewform');
  });

  test('accepts only Google Forms links carrying all placeholders', () {
    expect(SurveyRepository.isValidTemplate(template), isTrue);
    expect(
        SurveyRepository.isValidTemplate(
            'https://docs.google.com/forms/d/e/ABC/viewform?entry.1=CODIGO'),
        isFalse);
    expect(SurveyRepository.isValidTemplate('https://example.com/?a=CODIGO&b=ROL&c=VERSION'),
        isFalse);
  });

  test('tester code is derived from the uid, not personal data', () {
    expect(TesterIdentity.codeFor('4f9k2aXYZ123'), 'T-4F9K2A');
  });
}
