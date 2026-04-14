import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final dayStart = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await FirebaseFirestore.instance
        .collection('citas')
        .where('tecnicoId', isEqualTo: widget.technicianId)
        .where('fechaHora',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('fechaHora', isLessThan: Timestamp.fromDate(dayEnd))
        .where('estado', whereIn: ['programada', 'confirmada']).get();

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
              slotTime
                  .add(const Duration(minutes: 60))
                  .isAfter(appt.fechaHora);
        });

        if (!hasConflict) {
          slots.add(
              '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
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
    final availableSlots = _getAvailableSlots();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Agendar Cita',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Technician card
                        if (_technician != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0D7377),
                                        Color(0xFF14BDAC),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _technician!.nombre.isNotEmpty
                                          ? _technician!.nombre[0]
                                              .toUpperCase()
                                          : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _technician!.fullName,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF8E1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.star_rounded,
                                                    size: 14,
                                                    color: Colors.amber),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_technician!.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"}',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Appointment type
                        Text(
                          'Tipo de Cita',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TypeOption(
                                label: 'A Domicilio',
                                icon: Icons.home_outlined,
                                isSelected:
                                    _appointmentType == 'domicilio',
                                onTap: () => setState(
                                    () => _appointmentType = 'domicilio'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TypeOption(
                                label: 'En Taller',
                                icon: Icons.store_outlined,
                                isSelected:
                                    _appointmentType == 'taller',
                                onTap: () => setState(
                                    () => _appointmentType = 'taller'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Date selection
                        Text(
                          'Fecha',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 14,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final date = DateTime.now()
                                  .add(Duration(days: index + 1));
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
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  width: 64,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF0D7377),
                                              Color(0xFF14BDAC),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : isWeekend
                                            ? AppTheme.dividerColor
                                                .withValues(alpha: 0.5)
                                            : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                      0xFF14BDAC)
                                                  .withValues(
                                                      alpha: 0.35),
                                              blurRadius: 12,
                                              offset:
                                                  const Offset(0, 4),
                                            ),
                                          ]
                                        : AppTheme.softShadow,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('EEE')
                                            .format(date)
                                            .toUpperCase(),
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: isSelected
                                              ? Colors.white
                                                  .withValues(
                                                      alpha: 0.8)
                                              : AppTheme.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${date.day}',
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : isWeekend
                                                  ? AppTheme
                                                      .textTertiary
                                                  : AppTheme
                                                      .textPrimary,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM').format(date),
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                                  .withValues(
                                                      alpha: 0.8)
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
                        Text(
                          'Horarios Disponibles',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (availableSlots.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 40,
                                    color: AppTheme.textTertiary),
                                const SizedBox(height: 12),
                                Text(
                                  'No hay horarios disponibles\npara esta fecha',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.textTertiary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: availableSlots.map((slot) {
                              final isSelected = _selectedSlot == slot;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _selectedSlot = slot),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF0D7377),
                                              Color(0xFF14BDAC),
                                            ],
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                      0xFF14BDAC)
                                                  .withValues(
                                                      alpha: 0.3),
                                              blurRadius: 10,
                                              offset:
                                                  const Offset(0, 3),
                                            ),
                                          ]
                                        : AppTheme.softShadow,
                                  ),
                                  child: Text(
                                    slot,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: _selectedSlot != null
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF0D7377),
                                  Color(0xFF14BDAC),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: _selectedSlot == null
                            ? AppTheme.dividerColor
                            : null,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        boxShadow: _selectedSlot != null
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF14BDAC)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _booking || _selectedSlot == null
                              ? null
                              : _book,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_booking)
                                  const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.event_available_rounded,
                                    color: _selectedSlot != null
                                        ? Colors.white
                                        : AppTheme.textTertiary,
                                    size: 22,
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedSlot != null
                                      ? 'Agendar: ${DateFormat('dd/MM').format(_selectedDate)} a las $_selectedSlot'
                                      : 'Selecciona un horario',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _selectedSlot != null
                                        ? Colors.white
                                        : AppTheme.textTertiary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          gradient: isSelected
              ? null
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.softShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : AppTheme.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
