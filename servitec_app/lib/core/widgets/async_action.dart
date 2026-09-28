import 'package:flutter/material.dart';

/// Runs an action that talks to the backend, and makes a second tap impossible
/// while the first one is still in flight.
///
/// Every screen used to solve this on its own with a `bool _busy` field, which
/// is easy to forget on a new screen — QA found several buttons that could be
/// tapped repeatedly, sending the same request more than once. Wrapping a
/// button here is the one way to get it right:
///
/// ```dart
/// AsyncAction(
///   action: () => repo.aprobar(uid),
///   builder: (context, onPressed, busy) => ElevatedButton(
///     onPressed: onPressed, // null while busy
///     child: busy ? const ButtonSpinner() : const Text('Aprobar'),
///   ),
/// )
/// ```
///
/// The guard is local to the widget: the server enforces its own limits
/// (functions/src/lib/rate-limit.ts), because nothing in the app can stop a
/// request that never goes through the app.
class AsyncAction extends StatefulWidget {
  /// What to run on tap. Exceptions are handed to [onError] if given, and
  /// otherwise swallowed so the button always comes back to life.
  final Future<void> Function() action;

  /// Receives `null` for `onPressed` while the action runs.
  final Widget Function(BuildContext context, VoidCallback? onPressed, bool busy)
      builder;

  /// Disables the button for reasons of its own (invalid form, nothing
  /// selected…). The in-flight guard is on top of this.
  final bool enabled;

  final void Function(Object error)? onError;

  const AsyncAction({
    super.key,
    required this.action,
    required this.builder,
    this.enabled = true,
    this.onError,
  });

  @override
  State<AsyncAction> createState() => _AsyncActionState();
}

class _AsyncActionState extends State<AsyncAction> {
  bool _busy = false;

  Future<void> _run() async {
    // Re-entrancy guard as well as a disabled button: a tap already queued
    // when the first one started would otherwise slip through.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.action();
    } catch (err) {
      widget.onError?.call(err);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _busy || !widget.enabled ? null : _run, _busy);
}

/// The spinner that replaces a button's label while its action runs.
class ButtonSpinner extends StatelessWidget {
  final Color? color;
  final double size;

  const ButtonSpinner({super.key, this.color, this.size = 18});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color ?? Theme.of(context).colorScheme.onPrimary,
        ),
      );
}
