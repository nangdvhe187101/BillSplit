import 'package:flutter/material.dart';

/// Bảng màu Xanh Bầu Trời (Sky Blue) kết hợp Trắng Nhẹ (Soft White)
class AppColors {
  // Gam màu Xanh Bầu Trời chủ đạo
  static const Color primary = Color(0xFF0EA5E9);       // Sky Blue tươi sáng, hiện đại
  static const Color primaryDark = Color(0xFF0284C7);   // Xanh biển đậm cho nhấn mạnh
  static const Color primaryLight = Color(0xFFBAE6FD);  // Xanh trời nhạt cho viền và badge
  static const Color primarySoft = Color(0xFFE0F2FE);   // Xanh mây nền nhẹ nhàng

  // Gam màu Trắng & Nền
  static const Color background = Color(0xFFF8FAFC);    // Trắng mờ dịu mắt (Soft Off-White)
  static const Color surface = Color(0xFFFFFFFF);       // Trắng tinh khiết cho thẻ card
  static const Color surfaceVariant = Color(0xFFF1F5F9);// Xám trắng nhẹ cho input

  // Màu chữ & Đường viền
  static const Color textPrimary = Color(0xFF0F172A);   // Đen xanh đậm (Deep Slate)
  static const Color textSecondary = Color(0xFF64748B); // Xám trung tính
  static const Color textMuted = Color(0xFF94A3B8);     // Xám nhạt cho placeholder
  static const Color border = Color(0xFFE2E8F0);        // Viền thẻ mỏng nhẹ

  // Màu trạng thái tài chính
  static const Color success = Color(0xFF10B981);       // Xanh lá (tiền vào / đã trả)
  static const Color error = Color(0xFFEF4444);         // Đỏ (chưa trả / lỗi)
  static const Color warning = Color(0xFFF59E0B);       // Vàng cam cảnh báo
}

/// Cấu hình Theme chuẩn cho toàn bộ ứng dụng Flutter
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
