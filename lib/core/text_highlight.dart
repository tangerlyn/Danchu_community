import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Highlights all occurrences of [query] in [text] with bold styling.
Widget highlightText(
  String text,
  String query,
  TextStyle baseStyle, {
  int maxLines = 1,
}) {
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <TextSpan>[];
  int start = 0;

  while (start < text.length) {
    final idx = lowerText.indexOf(lowerQuery, start);
    if (idx == -1) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (idx > start) {
      spans.add(TextSpan(text: text.substring(start, idx)));
    }
    spans.add(TextSpan(
      text: text.substring(idx, idx + query.length),
      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.deepBrown),
    ));
    start = idx + query.length;
  }

  return RichText(
    text: TextSpan(style: baseStyle, children: spans),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  );
}

/// Builds a contextual body snippet with highlighted keyword.
/// Ensures the keyword is visible within a 2-line preview.
Widget buildContextSnippet(String content, String query) {
  final cleanedContent = content.replaceAll('\n', ' ').trim();
  final lowerContent = cleanedContent.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final matchIndex = lowerContent.indexOf(lowerQuery);

  if (matchIndex == -1) {
    return Text(
      cleanedContent,
      style: const TextStyle(fontSize: 14, color: AppColors.latte),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  const int contextBefore = 30;
  const int contextAfter = 60;

  if (matchIndex <= contextBefore) {
    final end = (matchIndex + query.length + contextAfter).clamp(0, cleanedContent.length);
    final text = cleanedContent.substring(0, end) + (end < cleanedContent.length ? '...' : '');
    return highlightText(
      text,
      query,
      const TextStyle(fontSize: 14, color: AppColors.latte),
      maxLines: 2,
    );
  }

  final snippetStart = (matchIndex - contextBefore).clamp(0, cleanedContent.length);
  final snippetEnd = (matchIndex + query.length + contextAfter).clamp(0, cleanedContent.length);
  final prefix = snippetStart > 0 ? '...' : '';
  final suffix = snippetEnd < cleanedContent.length ? '...' : '';
  final snippet = '$prefix${cleanedContent.substring(snippetStart, snippetEnd)}$suffix';

  return highlightText(
    snippet,
    query,
    const TextStyle(fontSize: 14, color: AppColors.latte),
    maxLines: 2,
  );
}
