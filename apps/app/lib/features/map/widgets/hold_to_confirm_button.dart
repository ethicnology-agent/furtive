import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Confirms a deliberate hold, with progress outside the finger's touch area.
class HoldToConfirmButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String shortTapHint;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final String? semanticHint;
  final String Function(int seconds)? progressLabel;

  const HoldToConfirmButton({
    super.key,
    required this.icon,
    required this.label,
    required this.shortTapHint,
    required this.onConfirmed,
    this.backgroundColor = const Color(0xFFE53935),
    this.foregroundColor = Colors.white,
    this.holdDuration = const Duration(seconds: 3),
    this.semanticHint,
    this.progressLabel,
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  OverlayEntry? _progress;
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant HoldToConfirmButton old) {
    super.didUpdateWidget(old);
    if (widget.holdDuration != old.holdDuration) {
      _cancel();
      _controller.duration = widget.holdDuration;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeProgress();
    _controller.dispose();
    super.dispose();
  }

  void _removeProgress() {
    _progress?.remove();
    _progress?.dispose();
    _progress = null;
  }

  Future<void> _start() async {
    if (_controller.isAnimating) return;
    unawaited(HapticFeedback.selectionClick());
    _progress = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final remaining =
                          (widget.holdDuration.inMilliseconds *
                                  (1 - _controller.value) /
                                  1000)
                              .ceil();
                      return Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.progressLabel?.call(remaining) ??
                                  '${widget.label}: $remaining',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.shortTapHint,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(value: _controller.value),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_progress!);
    try {
      await _controller.forward(from: 0).orCancel;
      if (!mounted) return;
      _removeProgress();
      unawaited(HapticFeedback.mediumImpact());
      widget.onConfirmed();
    } on TickerCanceled {
      // Releasing, leaving the app, or disposing cancels without confirming.
    }
  }

  void _cancel() {
    _controller.stop();
    _controller.reset();
    _removeProgress();
  }

  void _onShortTap() {
    if (_hintShown) return;
    _hintShown = true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.shortTapHint)));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.semanticHint ?? widget.shortTapHint,
      onTap: _onShortTap,
      onLongPress: _start,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: _onShortTap,
        onLongPressStart: (_) => _start(),
        onLongPressMoveUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null &&
              !(Offset.zero & box.size)
                  .inflate(12)
                  .contains(details.localPosition)) {
            _cancel();
          }
        },
        onLongPressEnd: (_) => _cancel(),
        onLongPressCancel: _cancel,
        child: Material(
          color: widget.backgroundColor,
          elevation: 6,
          shape: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.foregroundColor, size: 24),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: widget.foregroundColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
