import 'package:flutter/material.dart';

/// 코레일 공식 컬러 팔레트
class KorailColors {
  KorailColors._();

  // ── 브랜드 메인 컬러 ──
  static const Color korailBlue = Color(0xFF005BAC);
  static const Color skyBlue = Color(0xFF00B2E3);
  static const Color gray = Color(0xFF77777A);

  // ── 그라데이션 ──
  static const Color gradientStart = Color(0xFF005BAC);
  static const Color gradientEnd = Color(0xFF0073CF);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  // ── 배경 ──
  static const Color background = Color(0xFFF5F6F8);
  static const Color cardBackground = Colors.white;

  // ── 텍스트 ──
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color textOnBlue = Colors.white;

  // ── 시맨틱 컬러 (상태별) ──
  static const Color statusIdle = Color(0xFF9E9E9E);
  static const Color statusSearching = Color(0xFF1976D2);
  static const Color statusFound = Color(0xFF388E3C);
  static const Color statusReserving = Color(0xFFF57C00);
  static const Color statusSuccess = Color(0xFF2E7D32);
  static const Color statusFailure = Color(0xFFD32F2F);

  // ── 좌석 표시 ──
  static const Color seatAvailable = Color(0xFF388E3C);
  static const Color seatSoldOut = Color(0xFFBDBDBD);
}
