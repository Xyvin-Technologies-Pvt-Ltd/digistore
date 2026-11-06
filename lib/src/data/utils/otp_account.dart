/// Reads whether `/auth/send-otp` is for a number that does not have an
/// account yet. Null when the response does not say.
bool? isNewUserInOtpResponse(Map<String, dynamic>? body) {
  if (body == null) return null;
  for (final source in [body['data'], body]) {
    if (source is! Map) continue;
    final map = Map<String, dynamic>.from(source);
    if (map.containsKey('isNewUser')) return map['isNewUser'] == true;
    if (map.containsKey('isExistingUser')) return map['isExistingUser'] != true;
    if (map.containsKey('userExists')) return map['userExists'] != true;
    if (map['onboardingComplete'] == true) return false;
  }
  return null;
}
