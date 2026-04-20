import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../theme/app_colors.dart';

class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuPressed;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool showBack;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.onMenuPressed,
    this.actions,
    this.onBackPressed,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      leading: onMenuPressed != null
          ? IconButton(
              icon: Icon(Icons.menu, color: AppColors.white, size: 6.w),
              onPressed: onMenuPressed,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBack)
            Padding(
              padding: EdgeInsets.only(right: 2.w),
              child: InkWell(
                onTap: onBackPressed ?? () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Icon(Icons.arrow_back_ios_new, color: AppColors.white, size: 4.8.w),
              ),
            ),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 4.5.w,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}





