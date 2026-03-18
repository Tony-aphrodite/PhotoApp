import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String serviceId;
  final String technicianId;

  const BookAppointmentScreen({
    super.key,
    required this.serviceId,
    required this.technicianId,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  UserModel? _technician;
  List<AppointmentModel> _existingAppointments = [];
  bool _loading = true;
  bool _booking = false;
  String _appointmentType = 'domicilio';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final techDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.technicianId)
        .get();

    if (techDoc.exists) {
      _technician = UserModel.fromFirestore(techDoc);
    }

    await _loadAppointments();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAppointments() async {
    final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await FirebaseFirestore.instance
        .collection('citas')
        .where('tecnicoId', isEqualTo: widget.technicianId)
        .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('fechaHora', isLessThan: Timestamp.fromDate(dayEnd))
        .where('estado', whereIn: ['programada', 'confirmada'])
        .get();

    _existingAppointments =
        snap.docs.map((d) => AppointmentModel.fromFirestore(d)).toList();
  }

  List<String> _getAvailableSlots() {
    final slots = <String>[];
    // Generate slots from 8:00 to 18:00
    for (int hour = 8; hour < 18; hour++) {
      for (int min = 0; min < 60; min += 30) {
        final slotTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          min,
        );

        // Skip past times
        if (slotTime.isBefore(DateTime.now())) continue;

        // Check conflicts
        final hasConflict = _existingAppointments.any((appt) {
          return slotTime.isBefore(appt.endTime) &&
              slotTime.add(const Duration(minutes: 60)).isAfter(appt.fechaHora);
        });

        if (!hasConflict) {
          slots.add('${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
        }
      }
    }
    return slots;
  }

  Future<void> _book() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un horario')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _booking = true);

    try {
      final parts = _selectedSlot!.split(':');
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      final appointment = AppointmentModel(
        id: '',
        servicioId: widget.serviceId,
        tecnicoId: widget.technicianId,
        clienteId: authState.user.uid,
        fechaHora: dateTime,
        duracionMinutos: 60,
        estado: 'programada',
        tipo: _appointmentType,
      );

      await FirebaseFirestore.instance
          .collection('citas')
          .add(appointment.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cita programada: ${DateFormat('dd/MM/yyyy HH:mm').format(dateTime)}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableSlots = _getAvailableSlots();

    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Cita')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Technician info
                  if (_technician != null)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            _technician!.nombre.isNotEmpty
                                ? _technician!.nombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(_technician!.fullName),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${_technician!.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"}',
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Appointment type
                  Text('Tipo de Cita', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeOption(
                          label: 'A Domicilio',
                          icon: Icons.home_outlined,
                          isSelected: _appointmentType == 'domicilio',
                          onTap: () =>
                              setState(() => _appointmentType = 'domicilio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeOption(
                          label: 'En Taller',
                          icon: Icons.store_outlined,
                          isSelected: _appointmentType == 'taller',
                          onTap: () =>
                              setState(() => _appointmentType = 'taller'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Date picker
                  Text('Fecha', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14, // Next 14 days
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date =
                            DateTime.now().add(Duration(days: index + 1));
                        final isSelected =
                            _selectedDate.day == date.day &&
                                _selectedDate.month == date.month;
                        final isWeekend =
                            date.weekday == DateTime.sunday;

                        return GestureDetector(
                          onTap: isWeekend
                              ? null
                              : () async {
                                  setState(() {
                                    _selectedDate = date;
                                    _selectedSlot = null;
                                  });
                                  await _loadAppointments();
                                  setState(() {});
                                },
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : isWeekend
                                      ? AppTheme.dividerColor
                                          .withValues(alpha: 0.3)
                                      : null,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.dividerColor,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white70
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : isWeekend
                                            ? AppTheme.textTertiary
                                            : null,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM').format(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white70
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Time slots
                  Text('Horarios Disponibles',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),

                  if (availableSlots.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No hay horarios disponibles para esta fecha',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.textTertiary),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((slot) {
                        final isSelected = _selectedSlot == slot;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSlot = slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.dividerColor,
                              ),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected ? Colors.white : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed:
                        _booking || _selectedSlot == null ? null : _book,
                    icon: _booking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.event_available),
                    label: Text(_selectedSlot != null
                        ? 'Agendar: ${DateFormat('dd/MM').format(_selectedDate)} a las $_selectedSlot'
                        : 'Selecciona un horario'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
