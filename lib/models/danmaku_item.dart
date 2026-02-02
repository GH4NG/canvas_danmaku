import 'dart:ui' as ui;

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/utils/utils.dart';

class DanmakuItem<T> {
  /// 弹幕内容
  final DanmakuContentItem<T> content;

  /// 弹幕宽度
  double width;

  /// 弹幕高度
  double height;

  /// 弹幕水平方向位置
  double xPosition;

  /// 上次绘制时间
  int? drawTick;

  /// 弹幕布局缓存
  ui.Image? image;

  /// 弹幕图片加载缓存
  List<ui.Image>? loadedImages;

  bool expired = false;

  bool suspend = false;

  @pragma("vm:prefer-inline")
  bool needRemove(bool needRemove) {
    if (needRemove) {
      dispose();
    }
    return needRemove;
  }

  void dispose() {
    image?.dispose();
    image = null;
    loadedImages = null;
  }

  DanmakuItem({
    required this.content,
    required this.height,
    required this.width,
    this.xPosition = 0,
    this.image,
    this.loadedImages,
    this.drawTick,
  });

  void drawParagraphIfNeeded(
    double fontSize,
    int fontWeight,
    double strokeWidth,
  ) {
    if (image == null) {
      final paragraph = DmUtils.generateParagraph(
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );

      final hasImages = loadedImages != null && loadedImages!.isNotEmpty;
      final paragraphWidth = paragraph.maxIntrinsicWidth;
      final paragraphHeight = paragraph.height;

      image = DmUtils.recordDanmakuImage(
        contentParagraph: paragraph,
        content: content,
        fontSize: fontSize,
        fontWeight: fontWeight,
        strokeWidth: strokeWidth,
        images: loadedImages,
      );

      final displayText =
          content.imagesUrl != null && content.imagesUrl!.isNotEmpty
              ? DmUtils.parseTextWithImages(content.text)
              : content.text;

      final isImageOnly = loadedImages != null &&
          loadedImages!.isNotEmpty &&
          (displayText.trim().isEmpty ||
              !content.text.contains(RegExp(r'\[[^\]]+\]')));

      if (isImageOnly) {
        // 纯图片：多个表情用文字高度，单个表情用原始尺寸
        const imageSpacing = 6.0;
        final isMultipleImages = loadedImages!.length > 1;
        double totalImageWidth = 0.0;
        double maxImageHeight = 0.0;

        if (isMultipleImages) {
          // 多表情：缩放到文字高度
          final imageHeight = paragraphHeight;
          for (var img in loadedImages!) {
            final aspectRatio = img.width / img.height;
            final w = imageHeight * aspectRatio;
            totalImageWidth += w;
            maxImageHeight = imageHeight;
          }
        } else {
          // 单个表情：使用原始尺寸
          for (var img in loadedImages!) {
            final w = img.width.toDouble();
            final h = img.height.toDouble();
            totalImageWidth += w;
            if (h > maxImageHeight) maxImageHeight = h;
          }
        }

        totalImageWidth += (loadedImages!.length - 1) * imageSpacing;
        width = totalImageWidth + strokeWidth + (content.selfSend ? 4.0 : 0.0);
        height = maxImageHeight + strokeWidth;
      } else {
        width = paragraphWidth + strokeWidth + (content.selfSend ? 4.0 : 0.0);

        if (hasImages) {
          double imageWidth = 0.0;
          for (var img in loadedImages!) {
            imageWidth += paragraphHeight * (img.width / img.height);
          }
          width += imageWidth;
        }

        height = paragraphHeight + strokeWidth;
      }
      paragraph.dispose();
    }
  }

  @override
  String toString() {
    return 'DanmakuItem(content=$content, xPos=$xPosition, size=${ui.Size(width, height)}, drawTick=$drawTick)';
  }
}
