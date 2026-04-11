String? extractStudentIdFromEmail(String? email) {
  if (email == null) {
    return null;
  }

  final trimmed = email.trim().toLowerCase();
  if (trimmed.isEmpty || !trimmed.contains('@')) {
    return null;
  }

  final localPart = trimmed.split('@').first.trim();
  if (localPart.isEmpty) {
    return null;
  }

  final digitsOnly = RegExp(r'^\d{6,}$');
  if (!digitsOnly.hasMatch(localPart)) {
    return null;
  }

  return localPart;
}
