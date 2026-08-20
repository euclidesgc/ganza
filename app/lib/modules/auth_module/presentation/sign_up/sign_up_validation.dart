abstract final class SignUpValidation {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const passwordMinLength = 6;

  static bool isEmailValid(String value) =>
      _emailPattern.hasMatch(value.trim());

  static bool isPasswordValid(String value) =>
      value.length >= passwordMinLength;
}
