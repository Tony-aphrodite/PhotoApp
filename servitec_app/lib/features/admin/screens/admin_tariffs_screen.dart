import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/config_repository.dart';

class AdminTariffsScreen extends StatefulWidget {
  const AdminTariffsScreen({super.key});

  @override
  State<AdminTariffsScreen> createState() => _AdminTariffsScreenState();
}

class _AdminTariffsScreenState extends State<AdminTariffsScreen> {
  Map<String, TarifaInfo> _tarifas = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTarifas();
  }

  Future<void> _loadTarifas() async {
    final tarifas = await context.read<ConfigRepository>().getTarifas();
    if (mounted) {
      setState(() {
        _tarifas = tarifas;
        _loading = false;
      });
    }
  }

  void _editTarifa(String category, TarifaInfo tarifa) {
    final baseController =
        TextEditingController(text: tarifa.tarifaBase.toStringAsFixed(0));
    final urgentController =
        TextEditingController(text: tarifa.multiplicadorUrgente.toString());
    final kmController =
        TextEditingController(text: tarifa.recargoPorKm.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${AppConstants.categoryIcons[category] ?? ""} ${AppConstants.categoryLabels[category] ?? category}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: baseController,
              decoration: const InputDecoration(
                labelText: 'Tarifa Base (\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urgentController,
              decoration: const InputDecoration(
                labelText: 'Multiplicador Urgente',
                prefixIcon: Icon(Icons.flash_on),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kmController,
              decoration: const InputDecoration(
                labelText: 'Recargo por Km (\$)',
                prefixIcon: Icon(Icons.straighten),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBase = double.tryParse(baseController.text) ?? tarifa.tarifaBase;
              final newUrgent = double.tryParse(urgentController.text) ?? tarifa.multiplicadorUrgente;
              final newKm = double.tryParse(kmController.text) ?? tarifa.recargoPorKm;

              await context.read<ConfigRepository>().updateTarifa(category, {
                'descripcion': tarifa.descripcion,
                'tarifaBase': newBase,
                'multiplicadorUrgente': newUrgent,
                'recargoPorKm': newKm,
              });

              if (mounted) {
                Navigator.pop(ctx);
                _loadTarifas();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tarifa actualizada'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Tarifas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tarifas.isEmpty
              ? Center(
                  child: Text(
                    'No hay tarifas configuradas',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tarifas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = _tarifas.entries.elementAt(index);
                    final cat = entry.key;
                    final tarifa = entry.value;
                    final emoji = AppConstants.categoryIcons[cat] ?? '📋';
                    final label = AppConstants.categoryLabels[cat] ?? cat;

                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(label, style: theme.textTheme.titleSmall),
                        subtitle: Text(
                          'Base: \$${tarifa.tarifaBase.toStringAsFixed(0)} | Urgente: x${tarifa.multiplicadorUrgente} | Km: \$${tarifa.recargoPorKm}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppTheme.primaryColor),
                          onPressed: () => _editTarifa(cat, tarifa),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
