// MenyaCash logo loading spinner for Flutter.
// 1.  logo at  assets/images/menyacash_icon.png
// 2. In pubspec.yaml:
//        flutter:
//          assets:
//            - assets/images/menyacash_icon.png
//   3. Use it:
//        const MenyaLoader()                                   // Orbit, 96px
//        const MenyaLoader(style: MenyaLoaderStyle.sweep, size: 64)
//
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MenyaLoaderStyle {
  /// The rings turn in opposite directions, then lock back into the logo.
  orbit,

  /// A radar-style beam lights up a faded copy of the logo.
  sweep,

  /// The whole logo rotates steadily.
  spin,

  /// The logo gently grows and fades.
  pulse,
}

class MenyaLoader extends StatefulWidget {
  const MenyaLoader({
    super.key,
    this.style = MenyaLoaderStyle.orbit,
    this.size = 96,
    this.duration = const Duration(milliseconds: 1600),
    this.asset = 'assets/images/menyacash_icon.png',
    this.semanticsLabel = 'Loading',
  });

  final MenyaLoaderStyle style;
  final double size;

  /// Length of one cycle. Pulse uses 60% of this per half-breath.
  final Duration duration;
  final String asset;
  final String semanticsLabel;

  @override
  State<MenyaLoader> createState() => _MenyaLoaderState();
}

class _MenyaLoaderState extends State<MenyaLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _reduceMotion = false;

  Duration get _cycle {
    if (_reduceMotion) return const Duration(seconds: 4);
    return widget.style == MenyaLoaderStyle.pulse
        ? widget.duration * 0.6
        : widget.duration;
  }

  void _restart() {
    _c
      ..stop()
      ..duration = _cycle
      ..repeat(reverse: widget.style == MenyaLoaderStyle.pulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respects the "reduce motion" accessibility setting.
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _restart();
  }

  @override
  void didUpdateWidget(MenyaLoader old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style || old.duration != widget.duration) {
      _restart();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget get _logo => Image.asset(
        widget.asset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    final logo = _logo;
    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => switch (widget.style) {
              MenyaLoaderStyle.orbit => _orbit(logo, _c.value),
              MenyaLoaderStyle.sweep => _sweep(logo, _c.value),
              MenyaLoaderStyle.spin => Transform.rotate(
                  angle: _c.value * 2 * math.pi,
                  child: logo,
                ),
              MenyaLoaderStyle.pulse => _pulse(logo, _c.value),
            },
          ),
        ),
      ),
    );
  }

  // ---- Orbit -------------------------------------------------------------
  // The logo is cut into 3 rings (outer, middle, core) by radius.
  // Outer turns clockwise, middle counter-clockwise, core "breathes";
  // everything realigns for the last 25% of each cycle.
  Widget _orbit(Widget logo, double t) {
    final ringT = Curves.easeInOutCubic.transform((t / 0.75).clamp(0.0, 1.0));
    final angle = ringT * 2 * math.pi;

    final double coreScale;
    if (t < 0.35) {
      coreScale = 1 - 0.18 * Curves.easeInOut.transform(t / 0.35);
    } else if (t < 0.75) {
      coreScale = 0.82 + 0.18 * Curves.easeInOut.transform((t - 0.35) / 0.4);
    } else {
      coreScale = 1;
    }

    return Stack(
      children: [
        Transform.rotate(
          angle: angle,
          child: ClipPath(clipper: const _RingClipper(0.58, 1.05), child: logo),
        ),
        Transform.rotate(
          angle: -angle,
          child: ClipPath(clipper: const _RingClipper(0.25, 0.586), child: logo),
        ),
        Transform.scale(
          scale: coreScale,
          child: ClipPath(clipper: const _RingClipper(0, 0.256), child: logo),
        ),
      ],
    );
  }

  // ---- Sweep -------------------------------------------------------------
  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  Widget _sweep(Widget logo, double t) {
    return Stack(
      children: [
        Opacity(
          opacity: 0.18,
          child: ColorFiltered(colorFilter: _greyscale, child: logo),
        ),
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => SweepGradient(
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0, 300 / 360, 300.5 / 360],
            transform: GradientRotation(t * 2 * math.pi),
          ).createShader(rect),
          child: logo,
        ),
      ],
    );
  }

  // ---- Pulse -------------------------------------------------------------
  Widget _pulse(Widget logo, double t) {
    final e = Curves.easeInOut.transform(t);
    return Opacity(
      opacity: 0.55 + 0.45 * e,
      child: Transform.scale(scale: 0.86 + 0.14 * e, child: logo),
    );
  }
}

/// Clips to a ring between [inner] and [outer], given as fractions of the
/// widget's radius (half its width).
class _RingClipper extends CustomClipper<Path> {
  const _RingClipper(this.inner, this.outer);

  final double inner;
  final double outer;

  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: r * outer));
    if (inner > 0) {
      path.addOval(Rect.fromCircle(center: c, radius: r * inner));
    }
    return path;
  }

  @override
  bool shouldReclip(_RingClipper old) =>
      old.inner != inner || old.outer != outer;
}

// ---- Optional helper ------------------------------------------------------
/// Runs [task] while showing a full-screen overlay with the spinner,
/// and closes the overlay when the task finishes or fails.
///
///   final user = await showMenyaLoading(context, () => api.login(email, pw));
Future<T> showMenyaLoading<T>(
  BuildContext context,
  Future<T> Function() task, {
  MenyaLoaderStyle style = MenyaLoaderStyle.orbit,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(child: MenyaLoader(style: style)),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}