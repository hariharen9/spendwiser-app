import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A profile photo with an organic, non-circular blob mask.
///
/// Falls back to [fallback] when there is no Google photo URL, or when the
/// image cannot be loaded.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
    required this.fallback,
    this.onTap,
  });

  final String? photoUrl;
  final double size;
  final Widget fallback;
  final VoidCallback? onTap;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.photoUrl?.trim();
    final url =
        rawUrl != null &&
            rawUrl.isNotEmpty &&
            (rawUrl.startsWith('https://') || rawUrl.startsWith('http://'))
        ? rawUrl
        : null;

    if (url == null || _failed) return _wrap(widget.fallback);

    final c = context.spend;
    final avatar = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: const _BlobClipper(),
            child: ColoredBox(
              color: c.c2,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return ColoredBox(color: c.c2);
                },
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _BlobBorderPainter(c.ln))),
        ],
      ),
    );

    return _wrap(avatar);
  }

  Widget _wrap(Widget child) {
    if (widget.onTap == null) return child;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Smooth, asymmetric outline. Deliberately avoids a circular silhouette.
class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.52, h * 0.02)
      ..cubicTo(w * 0.78, h * 0.00, w * 0.98, h * 0.16, w * 0.95, h * 0.40)
      ..cubicTo(w * 0.93, h * 0.62, w * 0.86, h * 0.84, w * 0.64, h * 0.94)
      ..cubicTo(w * 0.44, h * 1.02, w * 0.18, h * 0.90, w * 0.06, h * 0.66)
      ..cubicTo(w * 0.00, h * 0.44, w * 0.06, h * 0.18, w * 0.24, h * 0.08)
      ..cubicTo(w * 0.32, h * 0.04, w * 0.42, h * 0.02, w * 0.52, h * 0.02)
      ..close();
  }

  @override
  bool shouldReclip(covariant _BlobClipper oldClipper) => false;
}

class _BlobBorderPainter extends CustomPainter {
  const _BlobBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _BlobClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
