import 'dart:math';
import 'dart:ui' as ui;

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';

abstract final class DmUtils {
  static const maxRasterizeSize = 8192.0;

  static double devicePixelRatio = 1;
  static final Paint _selfSendPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.green;

  static void updateSelfSendPaint(double strokeWidth) {
    _selfSendPaint.strokeWidth = strokeWidth;
  }

  static String parseTextWithImages(String text) {
    return text.replaceAll(RegExp(r'\[[^\]]+\]'), '');
  }

  static ui.Paragraph generateParagraph({
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      maxLines: 1,
    ));

    if (content.count case final count?) {
      builder
        ..pushStyle(ui.TextStyle(
          color: content.color,
          fontSize: fontSize * 0.6,
        ))
        ..addText('($count)')
        ..pop();
    }

    final displayText =
        content.imagesUrl != null && content.imagesUrl!.isNotEmpty
            ? parseTextWithImages(content.text)
            : content.text;

    builder
      ..pushStyle(ui.TextStyle(color: content.color, fontSize: fontSize))
      ..addText(displayText);

    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  static ui.Image recordDanmakuImage({
    required ui.Paragraph contentParagraph,
    required DanmakuContentItem content,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
    List<ui.Image>? images,
  }) {
    final displayText =
        content.imagesUrl != null && content.imagesUrl!.isNotEmpty
            ? parseTextWithImages(content.text)
            : content.text;

    final isImageOnly = images != null &&
        images.isNotEmpty &&
        (displayText.trim().isEmpty ||
            !content.text.contains(RegExp(r'\[[^\]]+\]')));

    double w = contentParagraph.maxIntrinsicWidth + strokeWidth;
    double h = contentParagraph.height + strokeWidth;

    if (images != null && images.isNotEmpty) {
      if (isImageOnly) {
        const imageSpacing = 6.0;
        final isMultipleImages = images.length > 1;
        w = 0;
        double maxHeight = 0;

        if (isMultipleImages) {
          final imageHeight = contentParagraph.height;
          for (var img in images) {
            final aspectRatio = img.width / img.height;
            w += imageHeight * aspectRatio;
            maxHeight = imageHeight;
          }
        } else {
          for (var img in images) {
            w += img.width / devicePixelRatio;
            final imgHeight = img.height / devicePixelRatio;
            if (imgHeight > maxHeight) maxHeight = imgHeight;
          }
        }

        w += (images.length - 1) * imageSpacing;
        w += strokeWidth;
        h = maxHeight + strokeWidth;
      } else {
        final imageHeight = h - strokeWidth;
        double totalImageWidth = 0;
        for (var img in images) {
          final aspectRatio = img.width / img.height;
          totalImageWidth += imageHeight * aspectRatio;
        }
        w += totalImageWidth;
      }
    }

    final offset = Offset(
      (strokeWidth / 2.0) + (content.selfSend ? 2.0 : 0.0),
      strokeWidth / 2.0,
    );

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    if (devicePixelRatio != 1) {
      canvas.scale(devicePixelRatio);
    }

    if (strokeWidth != 0) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontWeight: FontWeight.values[fontWeight],
        textDirection: TextDirection.ltr,
        maxLines: 1,
      ));
      final Paint strokePaint = Paint()
        ..shader = content.isColorful
            ? const LinearGradient(
                    colors: [Color(0xFFF2509E), Color(0xFF308BCD)])
                .createShader(Rect.fromLTWH(0, 0, w, h))
            : null
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      if (!content.isColorful) {
        strokePaint.color = Colors.black;
      }

      if (!isImageOnly) {
        if (content.count case final count?) {
          builder
            ..pushStyle(ui.TextStyle(
              fontSize: fontSize * 0.6,
              foreground: strokePaint,
            ))
            ..addText('($count)')
            ..pop();
        }

        final displayText =
            content.imagesUrl != null && content.imagesUrl!.isNotEmpty
                ? parseTextWithImages(content.text)
                : content.text;

        builder
          ..pushStyle(ui.TextStyle(fontSize: fontSize, foreground: strokePaint))
          ..addText(displayText);

        final strokeParagraph = builder.build()
          ..layout(const ui.ParagraphConstraints(width: double.infinity));

        canvas.drawParagraph(strokeParagraph, offset);
        strokeParagraph.dispose();
      }
    }

    if (!isImageOnly) {
      canvas.drawParagraph(contentParagraph, offset);
    }

    if (images != null && images.isNotEmpty) {
      if (isImageOnly) {
        const imageSpacing = 6.0;
        final isMultipleImages = images.length > 1;
        double currentX = offset.dx;
        for (var i = 0; i < images.length; i++) {
          final img = images[i];
          double imageWidth;
          double imageHeight;

          if (isMultipleImages) {
            final textHeight = contentParagraph.height;
            final aspectRatio = img.width / img.height;
            imageHeight = textHeight;
            imageWidth = textHeight * aspectRatio;
          } else {
            imageWidth = img.width / devicePixelRatio;
            imageHeight = img.height / devicePixelRatio;
          }

          final srcRect =
              Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
          final dstRect =
              Rect.fromLTWH(currentX, offset.dy, imageWidth, imageHeight);
          canvas.drawImageRect(img, srcRect, dstRect, Paint());
          currentX += imageWidth;
          if (i < images.length - 1) {
            currentX += imageSpacing;
          }
        }
      } else {
        double currentX = contentParagraph.maxIntrinsicWidth + offset.dx;
        final imageHeight = h - strokeWidth;

        for (var img in images) {
          final aspectRatio = img.width / img.height;
          final imageWidth = imageHeight * aspectRatio;

          final srcRect =
              Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
          final dstRect =
              Rect.fromLTWH(currentX, offset.dy, imageWidth, imageHeight);
          canvas.drawImageRect(img, srcRect, dstRect, Paint());

          currentX += imageWidth;
        }
      }
    }

    if (content.selfSend) {
      w += 4;
      canvas.drawRect(Rect.fromLTRB(0, 0, w, h), _selfSendPaint);
    }

    final pic = rec.endRecording();
    final img = pic.toImageSync(
      (w * devicePixelRatio).ceil(),
      (h * devicePixelRatio).ceil(),
    );
    pic.dispose();
    return img;
  }

  static ui.Image recordSpecialDanmakuImg({
    required SpecialDanmakuContentItem content,
    required int fontWeight,
    required double strokeWidth,
    List<ui.Image>? images,
  }) {
    final displayText =
        content.imagesUrl != null && content.imagesUrl!.isNotEmpty
            ? parseTextWithImages(content.text)
            : content.text;

    final isImageOnly = images != null &&
        images.isNotEmpty &&
        (displayText.trim().isEmpty ||
            !content.text.contains(RegExp(r'\[[^\]]+\]')));

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontWeight: FontWeight.values[fontWeight],
      textDirection: TextDirection.ltr,
      fontSize: content.fontSize,
    ))
      ..pushStyle(ui.TextStyle(
        color: content.color,
        fontSize: content.fontSize,
        shadows: content.hasStroke
            ? [Shadow(color: Colors.black, blurRadius: strokeWidth)]
            : null,
      ))
      ..addText(displayText);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));

    final strokeOffset = strokeWidth / 2;
    double totalWidth;
    double totalHeight;

    if (isImageOnly) {
      const imageSpacing = 6.0;
      final isMultipleImages = images.length > 1;
      double totalW = 0;
      double maxH = 0;

      if (isMultipleImages) {
        final imageHeight = paragraph.height;
        for (var img in images) {
          final aspectRatio = img.width / img.height;
          totalW += imageHeight * aspectRatio;
          maxH = imageHeight;
        }
      } else {
        for (var img in images) {
          totalW += img.width / devicePixelRatio;
          final h = img.height / devicePixelRatio;
          if (h > maxH) maxH = h;
        }
      }

      totalW += (images.length - 1) * imageSpacing;
      totalWidth = totalW + strokeWidth;
      totalHeight = maxH + strokeWidth;
    } else {
      totalWidth = paragraph.maxIntrinsicWidth + strokeWidth;
      totalHeight = paragraph.height + strokeWidth;

      double imageWidth = 0;
      if (images != null && images.isNotEmpty) {
        final imageHeight = paragraph.height;
        for (var img in images) {
          final aspectRatio = img.width / img.height;
          imageWidth += imageHeight * aspectRatio;
        }
        totalWidth += imageWidth;
      }
    }

    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);

    Rect rect;

    if (content.rotateZ != 0 || content.matrix != null) {
      rect = _calculateRotatedBounds(
        totalWidth,
        totalHeight,
        content.rotateZ,
        content.matrix,
      );

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.translate(strokeOffset - rect.left, strokeOffset - rect.top);

      if (content.matrix case final matrix?) {
        canvas.transform(matrix.storage);
      } else {
        canvas.rotate(content.rotateZ);
      }
      canvas.drawParagraph(paragraph, Offset.zero);

      if (images != null && images.isNotEmpty) {
        _drawSpecialDanmakuImages(
          canvas,
          images,
          isImageOnly ? strokeOffset : paragraph.maxIntrinsicWidth,
          isImageOnly ? strokeOffset : 0,
          isImageOnly ? totalHeight - strokeWidth : paragraph.height,
          devicePixelRatio,
          useOriginalSize: isImageOnly,
        );
      }
    } else {
      rect = Rect.fromLTRB(0, 0, totalWidth, totalHeight);

      if (devicePixelRatio != 1) {
        canvas.scale(devicePixelRatio);
      }
      canvas.drawParagraph(paragraph, Offset(strokeOffset, strokeOffset));
    }
    paragraph.dispose();

    double width = rect.width * devicePixelRatio;
    double height = rect.height * devicePixelRatio;
    if (width > maxRasterizeSize || height > maxRasterizeSize) {
      final scaledMaxSize = maxRasterizeSize / devicePixelRatio;
      final left = rect.left;
      final top = rect.top;
      double right = rect.right;
      double bottom = rect.bottom;

      if (width > maxRasterizeSize) {
        right = left + scaledMaxSize;
        width = maxRasterizeSize;
      }

      if (height > maxRasterizeSize) {
        bottom = top + scaledMaxSize;
        height = maxRasterizeSize;
      }

      rect = Rect.fromLTRB(left, top, right, bottom);

      if (images != null && images.isNotEmpty) {
        _drawSpecialDanmakuImages(
          canvas,
          images,
          isImageOnly
              ? strokeOffset
              : (paragraph.maxIntrinsicWidth + strokeOffset),
          strokeOffset,
          isImageOnly ? totalHeight - strokeWidth : paragraph.height,
          devicePixelRatio,
          useOriginalSize: isImageOnly,
        );
      }
    }

    content.rect = rect;

    final pic = rec.endRecording();
    final img = pic.toImageSync(width.ceil(), height.ceil());
    pic.dispose();

    return img;
  }

  static void _drawSpecialDanmakuImages(
    ui.Canvas canvas,
    List<ui.Image> images,
    double startX,
    double startY,
    double imageHeight,
    double devicePixelRatio, {
    bool useOriginalSize = false,
  }) {
    if (useOriginalSize) {
      const imageSpacing = 6.0;
      final isMultipleImages = images.length > 1;
      double currentX = startX;
      for (var i = 0; i < images.length; i++) {
        final img = images[i];
        double imageWidth;
        double actualHeight;

        if (isMultipleImages) {
          final aspectRatio = img.width / img.height;
          actualHeight = imageHeight;
          imageWidth = imageHeight * aspectRatio;
        } else {
          imageWidth = img.width / devicePixelRatio;
          actualHeight = img.height / devicePixelRatio;
        }

        final srcRect =
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dstRect =
            Rect.fromLTWH(currentX, startY, imageWidth, actualHeight);
        canvas.drawImageRect(img, srcRect, dstRect, Paint());

        currentX += imageWidth;
        if (i < images.length - 1) {
          currentX += imageSpacing;
        }
      }
    } else {
      double currentX = startX;
      for (var img in images) {
        final aspectRatio = img.width / img.height;
        final imageWidth = imageHeight * aspectRatio;

        final srcRect =
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dstRect =
            Rect.fromLTWH(currentX, startY, imageWidth, imageHeight);
        canvas.drawImageRect(img, srcRect, dstRect, Paint());

        currentX += imageWidth;
      }
    }
  }

  static Rect _calculateRotatedBounds(
    double w,
    double h,
    double rotateZ,
    Matrix4? matrix,
  ) {
    final double cosZ;
    final double cosY;
    final double sinZ;
    if (matrix == null) {
      cosZ = cos(rotateZ);
      sinZ = sin(rotateZ);
      cosY = 1;
    } else {
      cosZ = matrix[5];
      sinZ = matrix[1];
      cosY = matrix[10];
    }

    final wx = w * cosZ * cosY;
    final wy = w * sinZ;
    final hx = -h * sinZ * cosY;
    final hy = h * cosZ;

    final minX = _min4(0.0, wx, hx, wx + hx);
    final maxX = _max4(0.0, wx, hx, wx + hx);
    final minY = _min4(0.0, wy, hy, wy + hy);
    final maxY = _max4(0.0, wy, hy, wy + hy);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @pragma("vm:prefer-inline")
  static double _min4(double a, double b, double c, double d) {
    final ab = a < b ? a : b;
    final cd = c < d ? c : d;
    return ab < cd ? ab : cd;
  }

  @pragma("vm:prefer-inline")
  static double _max4(double a, double b, double c, double d) {
    final ab = a > b ? a : b;
    final cd = c > d ? c : d;
    return ab > cd ? ab : cd;
  }
}
