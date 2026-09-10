/// Password policy requirements state class
class PasswordRequirements {
  final bool hasMin8Chars;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const PasswordRequirements({
    required this.hasMin8Chars,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  bool get isStrong =>
      hasMin8Chars && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

  factory PasswordRequirements.check(String password) {
    return PasswordRequirements(
      hasMin8Chars: password.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasNumber: RegExp(r'[0-9]').hasMatch(password),
      hasSpecialChar: RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\+=/\\]').hasMatch(password),
    );
  }
}

/// Comprehensive form validators for the application
class Validators {
  /// Validate Full Name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Full name must be at least 2 characters';
    }
    // Must contain at least 2 alphabetic letters and valid characters only
    final letterCount = RegExp(r'[a-zA-Z]').allMatches(trimmed).length;
    if (letterCount < 2) {
      return 'Please enter a valid full name';
    }
    final validNameRegex = RegExp(r"^[a-zA-Z\s\.\'\-]+$");
    if (!validNameRegex.hasMatch(trimmed)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  /// Validate Email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate Indian 10-digit Phone Number (numeric digits only, 10 length, starts with 6-9)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    final firstChar = digitsOnly[0];
    if (!['6', '7', '8', '9'].contains(firstChar)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }
    return null;
  }

  /// Validate Password against security policy
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    final reqs = PasswordRequirements.check(value);
    if (!reqs.hasMin8Chars) {
      return 'Password must be at least 8 characters';
    }
    if (!reqs.isStrong) {
      return 'Password does not meet all policy requirements';
    }
    return null;
  }

  /// Validate Confirm Password matches original Password
  static String? validateConfirmPassword(String? confirmPassword, String? password) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Confirm password is required';
    }
    if (confirmPassword != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validate generic required text field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}