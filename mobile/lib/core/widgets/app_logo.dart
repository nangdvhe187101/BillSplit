import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Logo thương hiệu "Sổ Nợ": quyển sổ ghi công nợ cách điệu với dấu tích xác
/// nhận đã đối soát. Dùng chung cho AppBar, màn hình đăng nhập/đăng ký và
/// (sau này) splash screen để đồng bộ nhận diện thương hiệu toàn ứng dụng.
class AppLogo extends StatelessWidget {
  final double size;
  final bool withShadow;

  const AppLogo({super.key, this.size = 40, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: SvgPicture.asset(AppIcons.logoMark, width: size, height: size),
    );
  }
}

/// Icon SVG riêng của ứng dụng, dùng `currentColor` để nhận màu theo ngữ cảnh
/// (giống Icon Material) thay vì icon hệ thống chung cho mọi app.
class AppIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color color;

  const AppIcon({
    super.key,
    required this.assetPath,
    this.size = 24,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
