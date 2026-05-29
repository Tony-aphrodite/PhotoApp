import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/data/models/message_model.dart';

void main() {
  group('MessageModel.toFirestore', () {
    final now = DateTime.utc(2026, 5, 29, 12, 0, 0);

    test('text message serializes without imageData or metadata keys', () {
      final m = MessageModel(
        id: 'm1',
        userId: 'u1',
        nombreUsuario: 'Ana',
        mensaje: 'Hola',
        timestamp: now,
      );

      final map = m.toFirestore();
      expect(map['userId'], 'u1');
      expect(map['nombreUsuario'], 'Ana');
      expect(map['mensaje'], 'Hola');
      expect(map['tipo'], MessageModel.tipoTexto);
      expect(map['leido'], false);
      expect(map['timestamp'], isA<Timestamp>());
      expect((map['timestamp'] as Timestamp).toDate(), now);
      expect(map.containsKey('imageData'), isFalse);
      expect(map.containsKey('metadata'), isFalse);
    });

    test('image message includes imageData but skips metadata if absent', () {
      const dataUrl = 'data:image/jpeg;base64,AAAA';
      final m = MessageModel(
        id: '',
        userId: 'u1',
        nombreUsuario: 'Ana',
        mensaje: '',
        timestamp: now,
        tipo: MessageModel.tipoImagen,
        imageData: dataUrl,
      );

      final map = m.toFirestore();
      expect(map['tipo'], MessageModel.tipoImagen);
      expect(map['imageData'], dataUrl);
      expect(map.containsKey('metadata'), isFalse);
    });

    test('system message preserves metadata payload', () {
      final m = MessageModel(
        id: '',
        userId: 'system',
        nombreUsuario: 'ServiTec',
        mensaje: 'El técnico inició el servicio',
        timestamp: now,
        tipo: MessageModel.tipoSistema,
        metadata: {'event': 'status_change', 'estado': 'en_progreso'},
      );

      final map = m.toFirestore();
      expect(map['tipo'], MessageModel.tipoSistema);
      expect(map['userId'], 'system');
      expect(map['metadata'], isA<Map>());
      expect(map['metadata']['event'], 'status_change');
      expect(map['metadata']['estado'], 'en_progreso');
    });
  });

  group('MessageModel type predicates', () {
    final ts = DateTime.utc(2026, 5, 29);

    test('isImage true only for image tipo', () {
      expect(_msg(tipo: MessageModel.tipoTexto, ts: ts).isImage, isFalse);
      expect(_msg(tipo: MessageModel.tipoSistema, ts: ts).isImage, isFalse);
      expect(_msg(tipo: MessageModel.tipoImagen, ts: ts).isImage, isTrue);
    });

    test('isSystem true only for system tipo', () {
      expect(_msg(tipo: MessageModel.tipoTexto, ts: ts).isSystem, isFalse);
      expect(_msg(tipo: MessageModel.tipoImagen, ts: ts).isSystem, isFalse);
      expect(_msg(tipo: MessageModel.tipoSistema, ts: ts).isSystem, isTrue);
    });
  });

  group('MessageModel.tipo* constants', () {
    test('constants match the values used in Firestore', () {
      expect(MessageModel.tipoTexto, 'texto');
      expect(MessageModel.tipoImagen, 'imagen');
      expect(MessageModel.tipoSistema, 'sistema');
    });
  });
}

MessageModel _msg({required String tipo, required DateTime ts}) => MessageModel(
      id: 'x',
      userId: 'u',
      nombreUsuario: 'n',
      mensaje: 'm',
      timestamp: ts,
      tipo: tipo,
    );
