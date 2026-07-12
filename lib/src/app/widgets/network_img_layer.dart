import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zerobox/src/core/constants/style_constants.dart' as style;

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    this.width,
    this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.filterQuality = FilterQuality.high,
    this.color,
    this.colorBlendMode,
    this.fit = BoxFit.cover,
  });

  final String? src;
  final double? width;
  final double? height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BoxFit fit;

  static Widget heroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;

    return InheritedTheme.captureAll(
      heroContext,
      Material(type: MaterialType.transparency, child: fromHero.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = src ?? '';

    return imageUrl.isNotEmpty
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              type == 'avatar'
                  ? 50
                  : type == 'emote'
                  ? 0
                  : style.StyleConstants.imgRadius.x,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,
              fadeOutDuration:
                  fadeOutDuration ?? const Duration(milliseconds: 120),
              fadeInDuration:
                  fadeInDuration ?? const Duration(milliseconds: 120),
              filterQuality: filterQuality,
              color: color,
              colorBlendMode: colorBlendMode,
              errorWidget: (context, url, error) => _placeholder(context),
              placeholder: (context, url) => _placeholder(context),
            ),
          )
        : _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onInverseSurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(
          type == 'avatar'
              ? 50
              : type == 'emote'
              ? 0
              : style.StyleConstants.imgRadius.x,
        ),
      ),
      child: const Center(child: Icon(Icons.image_outlined)),
    );
  }
}

/// A network image with a fixed [height] whose width follows the image's
/// intrinsic aspect ratio. The loading/error placeholder keeps a portrait
/// 3:4 box instead of stretching to the available width.
class NetworkImgAutoWidth extends StatelessWidget {
  const NetworkImgAutoWidth({
    super.key,
    required this.src,
    required this.height,
    this.maxWidth = 560,
    this.fit = BoxFit.contain,
  });

  final String src;
  final double height;
  final double maxWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(style.StyleConstants.imgRadius.x),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
        child: CachedNetworkImage(
          imageUrl: src,
          height: height,
          fit: fit,
          fadeOutDuration: const Duration(milliseconds: 120),
          fadeInDuration: const Duration(milliseconds: 120),
          filterQuality: FilterQuality.high,
          placeholder: (context, url) => _placeholder(context),
          errorWidget: (context, url, error) => _placeholder(context),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: height * 3 / 4,
      height: height,
      color: Theme.of(
        context,
      ).colorScheme.onInverseSurface.withValues(alpha: 0.4),
      child: const Center(child: Icon(Icons.image_outlined)),
    );
  }
}
