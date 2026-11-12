import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_icons.dart';
import 'pressable.dart';

class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label);
  final T value;
  final String label;
}

/// A custom, anchored select menu with a fluid open/close transition.
///
/// The menu follows its field, flips above the field when there is not enough
/// space below, and reveals options with a short stagger. Selection and focus
/// states use the active accent colour, so the control inherits the app theme.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.margin = EdgeInsets.zero,
  });

  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final EdgeInsetsGeometry margin;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>>
    with SingleTickerProviderStateMixin {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  final _fieldKey = GlobalKey();

  late final AnimationController _animation;
  late final Animation<double> _menuCurve;
  late final Animation<double> _scrimFade;
  late final Animation<double> _menuScale;

  bool _isOpen = false;
  bool _openAbove = false;
  bool _alignRight = false;
  double _menuWidth = 220;
  double _maxMenuHeight = 340;

  AppSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 170),
    );
    _menuCurve = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrimFade = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _menuScale = Tween<double>(begin: 0.95, end: 1).animate(_menuCurve);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Alignment get _targetAnchor {
    if (_openAbove) {
      return _alignRight ? Alignment.topRight : Alignment.topLeft;
    }
    return _alignRight ? Alignment.bottomRight : Alignment.bottomLeft;
  }

  Alignment get _followerAnchor {
    if (_openAbove) {
      return _alignRight ? Alignment.bottomRight : Alignment.bottomLeft;
    }
    return _alignRight ? Alignment.topRight : Alignment.topLeft;
  }

  Alignment get _menuAlignment {
    if (_openAbove) {
      return _alignRight ? Alignment.bottomRight : Alignment.bottomLeft;
    }
    return _alignRight ? Alignment.topRight : Alignment.topLeft;
  }

  void _toggle() {
    if (_overlay.isShowing) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    FocusScope.of(context).unfocus();
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final view = MediaQuery.of(context);
    final screenHeight =
        view.size.height - view.viewInsets.bottom - view.padding.top;
    final below = screenHeight - origin.dy - size.height - 10;
    final above = origin.dy - 10;
    final openAbove = below < 220 && above > below;
    final available = openAbove ? above : below;
    final maxWidth = view.size.width - 24;
    final width = math.min(math.max(size.width, 210.0), maxWidth).toDouble();

    setState(() {
      _openAbove = openAbove;
      _alignRight = origin.dx + size.width > view.size.width / 2;
      _menuWidth = width;
      _maxMenuHeight = available.clamp(120.0, 340.0).toDouble();
      _isOpen = true;
    });
    _overlay.show();
    _animation.forward(from: 0);
  }

  Future<void> _close() async {
    if (!_overlay.isShowing) return;
    setState(() => _isOpen = false);
    await _animation.reverse();
    if (!mounted) return;
    _overlay.hide();
  }

  void _select(AppSelectOption<T> option) {
    if (option.value != widget.value) {
      widget.onChanged(option.value);
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final selected = _selected;
    final label = selected?.label ?? widget.hint ?? '';

    return Container(
      margin: widget.margin,
      child: Semantics(
        button: true,
        label: selected?.label ?? widget.hint ?? 'Select an option',
        child: OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: _buildOverlay,
          child: CompositedTransformTarget(
            link: _link,
            child: Pressable(
              onTap: _toggle,
              scale: 0.985,
              child: AnimatedContainer(
                key: _fieldKey,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: c.c2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isOpen ? c.ac.withValues(alpha: 0.55) : c.ln,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.ac.withValues(
                        alpha: _isOpen ? (c.dark ? 0.12 : 0.07) : 0,
                      ),
                      blurRadius: _isOpen ? 18 : 0,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.16),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          label,
                          key: ValueKey<Object?>(selected?.value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sans(
                            size: 13,
                            color: selected == null ? c.mu : c.tx,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: SpendIcon(
                        'chevronDown',
                        size: 16,
                        color: _isOpen ? c.ac : c.mu,
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

  Widget _buildOverlay(BuildContext overlayContext) {
    final c = overlayContext.spend;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: FadeTransition(
              opacity: _scrimFade,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: c.dark ? 0.18 : 0.06),
              ),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: _targetAnchor,
          followerAnchor: _followerAnchor,
          offset: Offset(0, _openAbove ? -6 : 6),
          child: _buildMenu(overlayContext, c),
        ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, SpendColors c) {
    final selected = _selected;
    final menuOffset = Tween<Offset>(
      begin: Offset(0, _openAbove ? 0.08 : -0.08),
      end: Offset.zero,
    ).animate(_menuCurve);
    return SizedBox(
      width: _menuWidth,
      child: FadeTransition(
        opacity: _menuCurve,
        child: SlideTransition(
          position: menuOffset,
          child: ScaleTransition(
            alignment: _menuAlignment,
            scale: _menuScale,
            child: Container(
              constraints: BoxConstraints(maxHeight: _maxMenuHeight),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: c.dark
                      ? const [Color(0xFF23232B), Color(0xFF17171D)]
                      : const [Color(0xFFFFFFFF), Color(0xFFF7F4EC)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: c.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: c.dark ? 0.38 : 0.14),
                    blurRadius: 30,
                    spreadRadius: -6,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            widget.hint ?? 'No options',
                            style: AppTypography.sans(size: 13, color: c.mu),
                          ),
                        )
                      else
                        for (var i = 0; i < widget.options.length; i++)
                          _MenuOption<T>(
                            key: ValueKey<Object?>(widget.options[i].value),
                            option: widget.options[i],
                            selected:
                                widget.options[i].value == selected?.value,
                            index: i,
                            count: widget.options.length,
                            animation: _animation,
                            onTap: () => _select(widget.options[i]),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuOption<T> extends StatelessWidget {
  const _MenuOption({
    super.key,
    required this.option,
    required this.selected,
    required this.index,
    required this.count,
    required this.animation,
    required this.onTap,
  });

  final AppSelectOption<T> option;
  final bool selected;
  final int index;
  final int count;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final start = (index / (count + 2)).clamp(0.0, 0.42).toDouble();
    final end = math.min(1.0, start + 0.58);
    final itemCurve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, end, curve: Curves.easeInCubic),
    );

    return FadeTransition(
      opacity: itemCurve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(itemCurve),
        child: Semantics(
          button: true,
          selected: selected,
          label: option.label,
          child: Pressable(
            onTap: onTap,
            scale: 0.98,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? c.ac.withValues(alpha: c.dark ? 0.13 : 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.sans(
                        size: 13,
                        color: selected ? c.ac : c.tx,
                        weight: selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: SpendIcon('check', size: 15, color: c.ac),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
