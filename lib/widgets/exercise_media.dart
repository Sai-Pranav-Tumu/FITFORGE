import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Renders a single exercise media frame (an animated GIF or a still image)
/// from a network URL, a local file, or a bundled asset.
///
/// Network media (e.g. exercise GIFs) is streamed and disk-cached on demand
/// instead of being bulk-downloaded. Animated GIFs play automatically. The
/// whole thing is wrapped in a [RepaintBoundary] so an animating GIF does not
/// trigger repaints of the surrounding UI (important inside lists).
class ExerciseMedia extends StatelessWidget {
  final String path;

  /// 'file' or 'asset'. Ignored when [path] is an http(s) URL.
  final String source;
  final BoxFit fit;
  final WidgetBuilder? fallbackBuilder;

  const ExerciseMedia({
    super.key,
    required this.path,
    required this.source,
    this.fit = BoxFit.cover,
    this.fallbackBuilder,
  });

  bool get _isNetwork =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context) =>
        fallbackBuilder?.call(context) ?? const SizedBox.shrink();

    Widget child;
    if (_isNetwork) {
      child = CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, _) => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, _, _) => fallback(context),
      );
    } else if (source == 'file') {
      child = Image.file(
        File(path),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => fallback(context),
      );
    } else {
      child = Image.asset(
        path,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => fallback(context),
      );
    }

    return RepaintBoundary(child: child);
  }
}
