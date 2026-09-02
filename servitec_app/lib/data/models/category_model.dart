import 'package:equatable/equatable.dart';

/// One service category, as stored under `configuracion/categorias`.
///
/// [key] is the stable identifier written onto services and técnico
/// specialties (`plomeria`, `electricidad`); [label] and [icon] are what the
/// UI shows and the admin may change. A category is never deleted — a service
/// from last year still references it — only deactivated, which hides it from
/// pickers while leaving existing records legible.
class CategoryModel extends Equatable {
  final String key;
  final String label;

  /// An emoji. The app renders it as text, which is why an admin can set it
  /// from a phone keyboard without shipping an icon font.
  final String icon;
  final bool activo;

  /// Display order in pickers; lower first.
  final int orden;

  const CategoryModel({
    required this.key,
    required this.label,
    required this.icon,
    this.activo = true,
    this.orden = 0,
  });

  factory CategoryModel.fromMap(String key, Map<String, dynamic> m) =>
      CategoryModel(
        key: key,
        label: m['label'] as String? ?? key,
        icon: m['icon'] as String? ?? '📋',
        activo: m['activo'] as bool? ?? true,
        orden: (m['orden'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'icon': icon,
        'activo': activo,
        'orden': orden,
      };

  CategoryModel copyWith({String? label, String? icon, bool? activo, int? orden}) =>
      CategoryModel(
        key: key,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        activo: activo ?? this.activo,
        orden: orden ?? this.orden,
      );

  @override
  List<Object?> get props => [key, label, icon, activo, orden];
}
