import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    return await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    try {
      final isAvailable =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your medical data',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
