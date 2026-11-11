import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 30px curved, drag-to-dismiss sheet with the prototype's 20px gutter.
Future<T?> showAppSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool isDismissible = true,
  bool enableDrag = true,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 280),
    ),
    builder: (sheetContext) => AppBottomSheet(
      scrollable: scrollable,
      child: Builder(builder: builder),
    ),
  );
}

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.spend;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.88;
    final handle = Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: c.c2,
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );

    if (!scrollable) {
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          height: maxHeight,
          decoration: BoxDecoration(
            color: c.c1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: c.ln, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  handle,
                  const SizedBox(height: 16),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: c.c1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: c.ln, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [handle, const SizedBox(height: 16), child],
            ),
          ),
        ),
      ),
    );
  }
}
