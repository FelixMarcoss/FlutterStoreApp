import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FaceTrackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FaceTrackAppBar({
    super.key,
    this.title = 'FaceTrack',
    this.subtitle,
    this.showBack = false,
    this.actions = const [],
    this.centerBrand = false,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;
  final bool centerBrand;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      centerTitle: centerBrand,
      automaticallyImplyLeading: false,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                tooltip: 'Voltar',
                onPressed: Navigator.of(context).pop,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            )
          : null,
      titleSpacing: showBack ? 4 : (centerBrand ? 0 : 16),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.center_focus_strong_rounded,
            color: AppColors.action,
            size: title == 'FaceTrack' ? 32 : 28,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: centerBrand
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: title == 'FaceTrack' ? 'Orbitron' : null,
                    fontWeight: FontWeight.w800,
                    fontSize: title == 'FaceTrack' ? 23 : 18,
                    letterSpacing: title == 'FaceTrack' ? 0.4 : 0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
