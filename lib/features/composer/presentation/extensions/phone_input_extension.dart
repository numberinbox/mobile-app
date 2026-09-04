extension PhoneInputExtension on String {
  bool get looksLikePhoneNumber {
    if (trim().isEmpty) return false;
    final cleaned = replaceAll(RegExp(r'[\s\-().]'), '');
    if (cleaned.isEmpty) return false;
    return RegExp(r'^\+?\d+$').hasMatch(cleaned);
  }
}
