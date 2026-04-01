import 'package:intl/intl.dart';

/// Formats a [DateTime] as a human-readable relative time string.
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inDays > 1) {
    return DateFormat('yyyy.MM.dd').format(time);
  } else if (difference.inDays == 1) {
    return '어제';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}시간 전';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}분 전';
  } else {
    return '방금 전';
  }
}
