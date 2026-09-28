import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/services/tester_identity.dart';
import 'package:servitec_app/data/repositories/survey_repository.dart';

void main() {
  const template = 'https://docs.google.com/forms/d/e/ABC/viewform'
      '?usp=pp_url&entry.111=CODIGO&entry.222=ROL&entry.333=VERSION';
  const plain = 'https://docs.google.com/forms/d/e/XYZ/viewform?usp=header';

  test('fills the three placeholders and keeps everything else', () {
    final uri = SurveyRepository.buildUri(template,
        codigo: 'T-4F9K2A', rol: 'cliente', version: '1.0.0+2');
    expect(uri.queryParameters['entry.111'], 'T-4F9K2A');
    expect(uri.queryParameters['entry.222'], 'cliente');
    expect(uri.queryParameters['entry.333'], '1.0.0+2');
    expect(uri.queryParameters['usp'], 'pp_url');
    expect(uri.path, '/forms/d/e/ABC/viewform');
  });

  test('a form without placeholders opens as is', () {
    final uri = SurveyRepository.buildUri(plain,
        codigo: 'T-4F9K2A', rol: 'tecnico', version: '1.0.0+2');
    expect(uri.toString(), plain);
    expect(SurveyRepository.isValidLink(plain), isTrue);
    expect(SurveyRepository.hasPlaceholders(plain), isFalse);
    expect(SurveyRepository.hasPlaceholders(template), isTrue);
  });

  test('accepts only Google Forms links', () {
    expect(SurveyRepository.isValidLink(template), isTrue);
    expect(SurveyRepository.isValidLink('https://forms.gle/abc123'), isTrue);
    expect(SurveyRepository.isValidLink('https://example.com/?a=CODIGO&b=ROL&c=VERSION'), isFalse);
    expect(SurveyRepository.isValidLink('https://docs.google.com/document/d/1'), isFalse);
  });

  test('each role gets its own link; the old single link covers both', () {
    final both = {'urlCliente': 'c', 'urlTecnico': 't'};
    expect(SurveyRepository.linkFor(both, SurveyRepository.rolCliente), 'c');
    expect(SurveyRepository.linkFor(both, SurveyRepository.rolTecnico), 't');
    final legacy = {'url': 'u'};
    expect(SurveyRepository.linkFor(legacy, SurveyRepository.rolTecnico), 'u');
    expect(SurveyRepository.linkFor({'urlCliente': 'c', 'urlTecnico': ' '}, SurveyRepository.rolTecnico), isNull);
    expect(SurveyRepository.linkFor(null, SurveyRepository.rolCliente), isNull);
  });

  test('tester code is derived from the uid, not personal data', () {
    expect(TesterIdentity.codeFor('4f9k2aXYZ123'), 'T-4F9K2A');
  });
}
