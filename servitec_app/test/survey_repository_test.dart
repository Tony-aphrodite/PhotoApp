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

  test("marketing's real links: all four filled, values URL-encoded", () {
    const tecnicos = 'https://docs.google.com/forms/d/e/1FAIpQLSfIiJUoxGsoCPCybWttXURKNTYp6prD1SftwazZFTC-E1TL6g/viewform'
        '?usp=pp_url&entry.792535534=CODIGO&entry.1481100291=ROL&entry.1058061812=VERSION&entry.618477738=ORIGEN';
    const clientes = 'https://docs.google.com/forms/d/e/1FAIpQLSeTgxO9a4ZO9UqHJuhAz6H1-dyFuN3-FtIi4HaBaVeWP9M_hw/viewform'
        '?usp=pp_url&entry.1212455301=CODIGO&entry.1397282804=ROL&entry.1007034681=VERSION&entry.1254564569=ORIGEN';
    expect(SurveyRepository.isValidLink(tecnicos), isTrue);
    expect(SurveyRepository.hasPlaceholders(tecnicos), isTrue);
    expect(SurveyRepository.hasPlaceholders(clientes), isTrue);

    final uri = SurveyRepository.buildUri(tecnicos,
        codigo: 'T-4F9K2A', rol: 'tecnico', version: '1.0.0+2', origen: 'app-android-pruebas');
    expect(uri.queryParameters['entry.792535534'], 'T-4F9K2A');
    expect(uri.queryParameters['entry.1481100291'], 'tecnico');
    expect(uri.queryParameters['entry.1058061812'], '1.0.0+2');
    expect(uri.queryParameters['entry.618477738'], 'app-android-pruebas');
    // A raw "+" in a query string reads as a space; it must travel as %2B.
    expect(uri.toString(), contains('entry.1058061812=1.0.0%2B2'));
    expect(uri.toString(), isNot(contains('ORIGEN')));
  });

  test('tester code is derived from the uid, not personal data', () {
    expect(TesterIdentity.codeFor('4f9k2aXYZ123'), 'T-4F9K2A');
  });
}
