import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Places every vial inside the playfield. Fixed 68×160 glass overflowed
/// once a board grew past eight vials (first happens at the 7-color vials).
class BottleBoardLayout {
  static const maxWidth = 68.0;
  static const aspect = 160.0 / 68.0;

  static List<Rect> of({required int count, required Size canvas}) {
    if (count <= 0 || canvas.width <= 0 || canvas.height <= 0) {
      return const [];
    }

    var bestCols = 1;
    var bestBw = -1.0;
    var bestGap = 12.0;
    var bestRowGap = 16.0;

    for (var cols = 1; cols <= count; cols++) {
      final rows = (count / cols).ceil();
      final gap = cols == 1 ? 0.0 : 12.0;
      final rowGap = rows == 1 ? 0.0 : 16.0;
      final bwByWidth = (canvas.width - (cols - 1) * gap) / cols;
      final bhByHeight = (canvas.height - (rows - 1) * rowGap) / rows;
      final bw = math.min(maxWidth, math.min(bwByWidth, bhByHeight / aspect));
      if (bw > bestBw) {
        bestBw = bw;
        bestCols = cols;
        bestGap = gap;
        bestRowGap = rowGap;
      }
    }

    final bw = bestBw;
    final bh = bw * aspect;
    final cols = bestCols;
    final rows = (count / cols).ceil();
    final totalW = cols * bw + (cols - 1) * bestGap;
    final totalH = rows * bh + (rows - 1) * bestRowGap;
    final ox = (canvas.width - totalW) / 2;
    final oy = math.max(0.0, (canvas.height - totalH) / 2);

    return [
      for (var i = 0; i < count; i++)
        Rect.fromLTWH(
          ox + (i % cols) * (bw + bestGap),
          oy + (i ~/ cols) * (bh + bestRowGap),
          bw,
          bh,
        ),
    ];
  }
}
