import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Service for biometric authentication (fingerprint, face recognition)
/// Provides secure authentication using device biometrics
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if biometric authentication is enrolled (at least one biometric registered)
  Future<bool> isBiometricEnrolled() async {
    try {
      return await _localAuth.isDeviceSupported() &&
             await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticate using biometrics
  /// Returns true if authentication is successful
  Future<bool> authenticate({
    String reason = 'Authenticate to access EduVerse',
    String? localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if biometrics are available
      if (!await isBiometricAvailable()) {
        return false;
      }

      // Check if biometrics are enrolled
      if (!await isBiometricEnrolled()) {
        return false;
      }

      // Perform authentication
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason ?? reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Only allow biometric, not device credentials
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      // Handle specific error codes
      if (e.code == 'lockedOut' || 
          e.code == 'userCancel' || 
          e.code == 'systemCancel' || 
          e.code == 'notEnrolled' || 
          e.code == 'notAvailable') {
        return false;
      }
      return false;
    }
  }

  /// Authenticate with device credentials (PIN, pattern, password)
  /// Falls back to this if biometrics are not available
  Future<bool> authenticateWithCredentials({
    String reason = 'Enter your device credentials',
    String? localizedReason,
  }) async {
    try {
      if (!await isBiometricAvailable()) {
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason ?? reason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false, // Allow device credentials
        ),
      );

      return didAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Stop any ongoing authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException {
      // Ignore errors when stopping
    }
  }

  /// Get the primary biometric type available
  Future<BiometricType?> getPrimaryBiometric() async {
    try {
      final available = await getAvailableBiometrics();
      if (available.isEmpty) return null;
      
      // Priority: face > fingerprint > iris
      if (available.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (available.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      } else if (available.contains(BiometricType.iris)) {
        return BiometricType.iris;
      }
      
      return available.first;
    } on PlatformException {
      return null;
    }
  }

  /// Get a user-friendly name for biometric type
  static String getBiometricTypeName(BiometricType type) {
    if (type == BiometricType.face) return 'Face Recognition';
    if (type == BiometricType.fingerprint) return 'Fingerprint';
    if (type == BiometricType.iris) return 'Iris Scan';
    return 'Biometric';
  }

  /// Get a user-friendly icon for biometric type
  static String getBiometricIcon(BiometricType type) {
    if (type == BiometricType.face) return '👤';
    if (type == BiometricType.fingerprint) return '👆';
    if (type == BiometricType.iris) return '👁️';
    return '🔐';
  }
}

/// Biometric authentication result
class BiometricResult {
  final bool success;
  final String? errorMessage;
  final BiometricErrorCode? errorCode;

  BiometricResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });

  factory BiometricResult.success() => BiometricResult(success: true);
  
  factory BiometricResult.error({
    required String message,
    BiometricErrorCode? code,
  }) => BiometricResult(
    success: false,
    errorMessage: message,
    errorCode: code,
  );
}

/// Biometric error codes
enum BiometricErrorCode {
  lockedOut,
  userCancel,
  systemCancel,
  notEnrolled,
  notAvailable,
  unknown,
}