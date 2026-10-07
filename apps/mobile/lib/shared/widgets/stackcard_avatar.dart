import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';

/// Текущее private изображение передаётся feature; внешний URL кешируется здесь.
class StackCardAvatar extends StatelessWidget {
  const StackCardAvatar({
    super.key,
    this.image,
    this.url = '',
    this.initials = '?',
    this.size = 80,
  });

  final Widget? image;
  final String url;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(initials, style: Theme.of(context).textTheme.titleLarge),
    );
    final uri = Uri.tryParse(url);
    final validUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return Semantics(
      label: context.strings.tr(
        validUrl || image != null ? 'media.avatar' : 'media.noAvatar',
      ),
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: context.colors.surfaceElevated,
            child:
                image ??
                (validUrl
                    ? CachedNetworkImage(
                        imageUrl: url,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => fallback,
                        errorWidget: (_, _, _) => fallback,
                      )
                    : fallback),
          ),
        ),
      ),
    );
  }
}
