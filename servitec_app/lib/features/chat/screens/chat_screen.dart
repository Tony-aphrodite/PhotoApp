import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_info_filter.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ChatScreen extends StatefulWidget {
  final String serviceId;

  const ChatScreen({super.key, required this.serviceId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _uploadingImage = false;

  // Lazy loading older messages
  final List<MessageModel> _olderMessages = [];
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOlderMessages(DateTime oldestTimestamp) async {
    if (_loadingOlder || !_hasMoreOlder) return;
    setState(() => _loadingOlder = true);

    try {
      final older = await context
          .read<ServiceRepository>()
          .getMessagesBefore(widget.serviceId, oldestTimestamp);

      if (mounted) {
        setState(() {
          // Prepend older messages, avoid duplicates by id
          final existingIds = _olderMessages.map((m) => m.id).toSet();
          final newOlder =
              older.where((m) => !existingIds.contains(m.id)).toList();
          _olderMessages.insertAll(0, newOlder);
          _hasMoreOlder = older.length >= 30;
          _loadingOlder = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Block off-platform contact-info sharing client-side. Server-side
    // enforcement (Cloud Function on message create) is the real boundary —
    // tracked in 5-29.md section 4.
    final violation = ContactInfoFilter.scan(text);
    if (violation != null) {
      _showViolationSnackbar(violation);
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    final message = MessageModel(
      id: '',
      userId: user.uid,
      nombreUsuario: user.fullName,
      mensaje: text,
      timestamp: DateTime.now(),
    );

    context.read<ServiceRepository>().sendMessage(widget.serviceId, message);
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    if (_uploadingImage) return;

    final source = await _showImageSourceSheet();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 75,
    );
    if (picked == null) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    setState(() => _uploadingImage = true);
    try {
      final storageRepo = context.read<StorageRepository>();
      final dataUrl = await storageRepo.uploadChatImage(File(picked.path));
      await context.read<ServiceRepository>().sendImageMessage(
            serviceId: widget.serviceId,
            userId: user.uid,
            userName: user.fullName,
            imageDataUrl: dataUrl,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar la imagen: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.primaryColor),
              title: Text(
                'Tomar foto',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.primaryColor),
              title: Text(
                'Elegir de galería',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showViolationSnackbar(ContactViolation violation) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                violation.message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) return 'Hoy';
    if (messageDay == today.subtract(const Duration(days: 1))) return 'Ayer';
    return DateFormat('dd MMM yyyy').format(date);
  }

  bool _shouldShowDateHeader(
      List<MessageModel> messages, int index) {
    if (index == 0) return true;
    final prev = messages[index - 1].timestamp;
    final curr = messages[index].timestamp;
    return prev.day != curr.day ||
        prev.month != curr.month ||
        prev.year != curr.year;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final currentUserId = authState.user.uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Chat del Servicio',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const _InAppCommsBanner(),
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: context
                  .read<ServiceRepository>()
                  .getMessages(widget.serviceId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                final streamMessages = snapshot.data ?? [];

                // Merge older + stream messages (no duplicates)
                final streamIds = streamMessages.map((m) => m.id).toSet();
                final dedupedOlder = _olderMessages
                    .where((m) => !streamIds.contains(m.id))
                    .toList();
                final allMessages = [...dedupedOlder, ...streamMessages];

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded,
                              size: 48, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No hay mensajes aun',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Envia el primer mensaje',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // First message timestamp for lazy load cursor
                final oldestTimestamp = allMessages.first.timestamp;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: allMessages.length + 1, // +1 for header
                  itemBuilder: (context, index) {
                    // Header: "Load older" button
                    if (index == 0) {
                      if (!_hasMoreOlder) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: _loadingOlder
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AppTheme.softShadow,
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _loadOlderMessages(oldestTimestamp),
                                    icon: const Icon(Icons.history,
                                        size: 16,
                                        color: AppTheme.primaryColor),
                                    label: Text(
                                      'Cargar mensajes anteriores',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }

                    final msgIndex = index - 1;
                    final message = allMessages[msgIndex];
                    final isMe = message.userId == currentUserId;
                    final isSystem = message.isSystem;

                    if (isSystem) {
                      return _SystemMessage(message: message);
                    }

                    // Date header
                    Widget? dateHeader;
                    if (_shouldShowDateHeader(allMessages, msgIndex)) {
                      dateHeader = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _formatDateHeader(message.timestamp),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (dateHeader != null) dateHeader,
                        _ChatBubble(
                          message: message,
                          isMe: isMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach image button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _uploadingImage ? null : _sendImage,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: _uploadingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined,
                                  color: AppTheme.primaryColor, size: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textTertiary,
                            fontSize: 15,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF14BDAC).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _sendMessage,
                        customBorder: const CircleBorder(),
                        child: const Center(
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InAppCommsBanner extends StatelessWidget {
  const _InAppCommsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No compartas teléfonos, correos ni enlaces externos. Tu protección aplica solo dentro de ServiTec.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14BDAC), Color(0xFF69F0AE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  message.nombreUsuario.isNotEmpty
                      ? message.nombreUsuario[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: message.isImage
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF0A6B6E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? const Color(0xFF0A6B6E).withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && !message.isImage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.nombreUsuario,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  if (message.isImage)
                    _ImageContent(message: message)
                  else
                    Text(
                      message.mensaje,
                      style: GoogleFonts.plusJakartaSans(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  Padding(
                    padding: message.isImage
                        ? const EdgeInsets.only(top: 4, right: 6, bottom: 2)
                        : const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: GoogleFonts.plusJakartaSans(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppTheme.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final MessageModel message;

  const _ImageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final dataUrl = message.imageData;
    if (dataUrl == null || dataUrl.isEmpty) {
      return Container(
        width: 200,
        height: 160,
        color: AppTheme.dividerColor,
        child: const Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 32),
      );
    }

    try {
      final b64 = dataUrl.split(',').last;
      final Uint8List bytes = base64Decode(b64);
      return GestureDetector(
        onTap: () => _openFullscreen(context, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 220,
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: 200,
        height: 160,
        color: AppTheme.dividerColor,
        child: const Icon(Icons.broken_image_outlined,
            color: Colors.white54, size: 32),
      );
    }
  }

  void _openFullscreen(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(child: Image.memory(bytes)),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final MessageModel message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.mensaje,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
