import 'dart:math' as math;
import 'package:flutter/material.dart';

enum StampSize {
  compact, // For list/search/bookmark thumbnails (60x80)
  regular, // For home banner & medium cards
  large, // For detail screen hero poster
}

class SoldOutStamp extends StatelessWidget {
  final StampSize size;
  final bool showOverlay;

  const SoldOutStamp({
    super.key,
    this.size = StampSize.regular,
    this.showOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize;
    final double subFontSize;
    final double horizontalPadding;
    final double verticalPadding;
    final double borderWidth;
    final double borderRadius;

    switch (size) {
      case StampSize.compact:
        fontSize = 11;
        subFontSize = 8;
        horizontalPadding = 6;
        verticalPadding = 2;
        borderWidth = 1.5;
        borderRadius = 4;
        break;
      case StampSize.regular:
        fontSize = 16;
        subFontSize = 10;
        horizontalPadding = 14;
        verticalPadding = 6;
        borderWidth = 2.5;
        borderRadius = 8;
        break;
      case StampSize.large:
        fontSize = 24;
        subFontSize = 14;
        horizontalPadding = 22;
        verticalPadding = 10;
        borderWidth = 3.5;
        borderRadius = 12;
        break;
    }

    Widget stampContent = Transform.rotate(
      angle: -10 * (math.pi / 180), // -10도 회전된 스탬프 효과
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: const Color(0xFFFF3B30), // 강렬한 스탬프 레드
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '매진',
              style: TextStyle(
                color: const Color(0xFFFF3B30),
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
            Text(
              'SOLD OUT',
              style: TextStyle(
                color: const Color(0xFFFF3B30),
                fontWeight: FontWeight.w800,
                fontSize: subFontSize,
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );

    if (showOverlay) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: stampContent,
        ),
      );
    }

    return stampContent;
  }
}
