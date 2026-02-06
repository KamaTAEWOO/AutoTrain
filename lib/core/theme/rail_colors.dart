import 'package:flutter/material.dart';
import '../constants/rail_type.dart';

/// 철도 사업자별 브랜드 색상
class RailColors {
  RailColors._();

  // ── KTX 색상 ──
  static const Color _ktxPrimary = Color(0xFF005BAC);
  static const Color _ktxGradientStart = Color(0xFF005BAC);
  static const Color _ktxGradientEnd = Color(0xFF0073CF);

  // ── SRT 색상 ──
  static const Color _srtPrimary = Color(0xFF7B2D8E);
  static const Color _srtGradientStart = Color(0xFF7B2D8E);
  static const Color _srtGradientEnd = Color(0xFF9B47B2);

  /// 브랜드 메인 색상
  static Color primary(RailType type) => switch (type) {
        RailType.ktx => _ktxPrimary,
        RailType.srt => _srtPrimary,
      };

  /// 브랜드 그라데이션
  static LinearGradient gradient(RailType type) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: switch (type) {
          RailType.ktx => [_ktxGradientStart, _ktxGradientEnd],
          RailType.srt => [_srtGradientStart, _srtGradientEnd],
        },
      );

  /// 보조 색상 (skyBlue 계열)
  static Color accent(RailType type) => switch (type) {
        RailType.ktx => const Color(0xFF00B2E3),
        RailType.srt => const Color(0xFFBB86FC),
      };
}
