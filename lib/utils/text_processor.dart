import 'dart:convert';

class TextProcessor {
  /// 处理Minecraft MOTD文本，解决中文乱码问题
  static String processMotd(String motd) {
    if (motd.isEmpty) return motd;

    // 1. 先尝试解码Unicode转义序列
    String processed = _decodeUnicodeEscapes(motd);

    // 2. 移除Minecraft格式化代码
    processed = _removeFormattingCodes(processed);

    // 3. 处理可能的编码问题
    processed = _fixEncodingIssues(processed);

    return processed.trim();
  }

  /// 解码Unicode转义序列
  static String _decodeUnicodeEscapes(String text) {
    try {
      // 处理 \uXXXX 格式的Unicode转义
      return text.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
            (Match m) {
          try {
            return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
          } catch (e) {
            return m.group(0)!;
          }
        },
      );
    } catch (e) {
      return text;
    }
  }

  /// 移除Minecraft格式化代码 (§符号及其后的字符)
  static String _removeFormattingCodes(String text) {
    final buffer = StringBuffer();
    bool skipNext = false;

    for (int i = 0; i < text.length; i++) {
      if (skipNext) {
        skipNext = false;
        continue;
      }

      if (text[i] == '§' && i + 1 < text.length) {
        // 跳过格式化代码
        skipNext = true;
        continue;
      }

      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  /// 修复编码问题
  static String _fixEncodingIssues(String text) {
    // 尝试检测和处理常见的编码问题
    if (_looksLikeEncoded(text)) {
      try {
        // 尝试从Latin-1解码为UTF-8
        final latin1Bytes = latin1.encode(text);
        return utf8.decode(latin1Bytes, allowMalformed: true);
      } catch (e) {
        // 如果失败，返回原始文本
        return text;
      }
    }

    return text;
  }

  /// 检查文本是否看起来像被错误编码
  static bool _looksLikeEncoded(String text) {
    // 检查是否包含常见的中文乱码模式
    final regex = RegExp(r'[Ã§Â±Ã¤Ã¶Ã¼ÃŸ]');
    return regex.hasMatch(text);
  }

  /// 处理可能的多重编码问题
  static String deepDecode(String text) {
    if (text.isEmpty) return text;

    String processed = text;

    // 多次尝试解码，直到文本不再变化
    String previous;
    do {
      previous = processed;
      processed = _decodeUnicodeEscapes(processed);
      processed = _removeFormattingCodes(processed);

      // 尝试UTF-8解码
      try {
        final bytes = latin1.encode(processed);
        final decoded = utf8.decode(bytes, allowMalformed: true);
        if (decoded != processed) {
          processed = decoded;
        }
      } catch (e) {
        // 忽略解码错误
      }

    } while (processed != previous && processed.length < 1000); // 安全限制

    return processed;
  }

  /// 检查文本是否包含中文字符
  static bool containsChinese(String text) {
    final regex = RegExp(r'[\u4e00-\u9fff]');
    return regex.hasMatch(text);
  }

  /// 获取文本的编码信息（用于调试）
  static Map<String, dynamic> getEncodingInfo(String text) {
    final info = <String, dynamic>{
      'length': text.length,
      'containsChinese': containsChinese(text),
      'containsUnicodeEscapes': text.contains(RegExp(r'\\u[0-9a-fA-F]{4}')),
      'containsFormattingCodes': text.contains('§'),
    };

    // 分析字符分布
    final chineseChars = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    final latinChars = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');

    info['chineseCharacterCount'] = chineseChars.length;
    info['latinCharacterCount'] = latinChars.length;

    return info;
  }
}