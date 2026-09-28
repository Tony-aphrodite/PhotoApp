import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';

/// Edit the service categories: rename, change the emoji, hide from pickers,
/// reorder, or add a new one.
///
/// Categories were a hardcoded list in AppConstants; changing one meant a new
/// APK. They now live in `configuracion/categorias` and every picker reads
/// CategoryCatalog. Nothing is ever deleted — a category is deactivated
/// instead, so services and técnico profiles that reference it stay legible.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late final CategoryRepository _repo;
  late final Stream<List<CategoryModel>> _stream;

  @override
  void initState() {
    super.initState();
    _repo = context.read<CategoryRepository>();
    // First admin visit writes the hardcoded defaults into Firestore. Until
    // then every client has been reading the same list from AppConstants, so
    // seeding changes nothing for users.
    _repo.seedIfMissing();
    _stream = _repo.watch();
  }

  /// Guards against a second tap while the dialog is open or the write is in
  /// flight — two dialogs on top of each other would save twice.
  bool _editing = false;

  Future<void> _edit(CategoryModel? existing) async {
    if (_editing) return;
    _editing = true;
    try {
      await _editDialog(existing);
    } finally {
      _editing = false;
    }
  }

  Future<void> _editDialog(CategoryModel? existing) async {
    final result = await showDialog<CategoryModel>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.upsert(result);
      messenger.showSnackBar(SnackBar(
        content: Text(existing == null ? 'Categoría creada.' : 'Categoría actualizada.'),
        backgroundColor: AppTheme.successColor,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo guardar: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  Future<void> _toggle(CategoryModel c) =>
      _repo.upsert(c.copyWith(activo: !c.activo));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Categorías',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _stream,
        builder: (context, snap) {
          final cats = snap.data ?? CategoryRepository.defaults;
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: cats.length,
            onReorder: (oldI, newI) {
              final keys = cats.map((c) => c.key).toList();
              if (newI > oldI) newI--;
              final k = keys.removeAt(oldI);
              keys.insert(newI, k);
              _repo.reorder(keys);
            },
            itemBuilder: (context, i) {
              final c = cats[i];
              return Container(
                key: ValueKey(c.key),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.softShadow,
                ),
                child: ListTile(
                  leading: Text(c.icon, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    c.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: c.activo ? AppTheme.textPrimary : AppTheme.textTertiary,
                      decoration: c.activo ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      c.key,
                      if (c.isDiagnostic)
                        'diagnóstico ${CurrencyFormatter.format(c.precioDiagnostico)}',
                      if (!c.activo) 'oculta',
                    ].join('  ·  '),
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: c.activo,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (_) => _toggle(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _edit(c),
                      ),
                      const Icon(Icons.drag_handle_rounded, color: AppTheme.textTertiary),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? existing;
  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _key;
  late final TextEditingController _label;
  late final TextEditingController _icon;
  late final TextEditingController _precio;
  late final TextEditingController _clave;
  late final TextEditingController _claveDiag;
  late bool _diagnostico;
  String? _precioError;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.existing?.key ?? '');
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _icon = TextEditingController(text: widget.existing?.icon ?? '📋');
    _diagnostico = widget.existing?.flujo == CategoryModel.flujoDiagnostico;
    final p = widget.existing?.precioDiagnostico ?? 0;
    _precio = TextEditingController(text: p > 0 ? p.toStringAsFixed(0) : '');
    _clave = TextEditingController(text: widget.existing?.claveProdServ ?? '');
    _claveDiag = TextEditingController(text: widget.existing?.claveDiagnostico ?? '');
  }

  @override
  void dispose() {
    _key.dispose();
    _label.dispose();
    _icon.dispose();
    _precio.dispose();
    _clave.dispose();
    _claveDiag.dispose();
    super.dispose();
  }

  /// `plomeria`, `aire_acondicionado` — lowercase, no accents, underscores.
  /// This is the value stored on every service, so it must be stable and safe.
  static String _slug(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  void _save() {
    final label = _label.text.trim();
    final icon = _icon.text.trim();
    // The key is fixed once created — services already point at it.
    final key = widget.existing?.key ?? _slug(_key.text.isEmpty ? label : _key.text);
    if (label.isEmpty || key.isEmpty) return;
    final precio = double.tryParse(_precio.text.trim()) ?? 0;
    if (_diagnostico && precio < 10) {
      setState(() => _precioError = 'Indica el precio de la visita (mínimo \$10)');
      return;
    }
    Navigator.pop(
      context,
      (widget.existing ??
              CategoryModel(key: key, label: label, icon: icon, orden: 999))
          .copyWith(
        label: label,
        icon: icon.isEmpty ? '📋' : icon,
        flujo: _diagnostico ? CategoryModel.flujoDiagnostico : CategoryModel.flujoEstandar,
        precioDiagnostico: _diagnostico ? precio : 0,
        claveProdServ: _clave.text.trim(),
        claveDiagnostico: _diagnostico ? _claveDiag.text.trim() : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      title: Text(isNew ? 'Nueva categoría' : 'Editar categoría',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Nombre visible'),
            textCapitalization: TextCapitalization.sentences,
          ),
          TextField(
            controller: _icon,
            decoration: const InputDecoration(labelText: 'Emoji'),
            maxLength: 4,
          ),
          if (isNew)
            TextField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'Identificador (opcional)',
                helperText: 'Se genera del nombre si lo dejas vacío. No se puede cambiar después.',
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Identificador: ${widget.existing!.key}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textTertiary)),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _diagnostico,
            onChanged: (v) => setState(() => _diagnostico = v),
            title: Text('Requiere visita de diagnóstico',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'El cliente paga la visita antes de que el técnico vaya; se descuenta si aprueba la reparación. '
              'Aplica a solicitudes nuevas.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          if (_diagnostico)
            TextField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Precio de la visita (MXN, IVA incluido)',
                prefixText: '\$ ',
                errorText: _precioError,
              ),
              onChanged: (_) => setState(() => _precioError = null),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _clave,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Clave SAT del servicio (ClaveProdServ)',
              helperText: 'La que indique el contador. Si la dejas vacía se usa la clave genérica 81111500.',
              helperMaxLines: 3,
              counterText: '',
            ),
          ),
          if (_diagnostico)
            TextField(
              controller: _claveDiag,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Clave SAT del diagnóstico',
                helperText: 'Se usa en el CFDI de la visita de diagnóstico.',
                helperMaxLines: 2,
                counterText: '',
              ),
            ),
        ],
      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
