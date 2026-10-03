import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The narrow slice of `flutter_secure_storage` `KeyRepositoryImpl` needs,
/// behind an interface so a fake can stand in for it in tests without a
/// platform channel (`flutter_secure_storage` has none available off a
/// device).
abstract interface class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// R-009: default `AndroidOptions()` — RSA-OAEP key wrapping over AES-GCM
/// against the Android Keystore. Deliberately not `AndroidOptions.biometric()`:
/// a biometric prompt to read your own key on every turn is friction with
/// no threat model behind it.
class FlutterSecureKeyStore implements SecureKeyStore {
  const FlutterSecureKeyStore([
    this._storage = const FlutterSecureStorage(aOptions: AndroidOptions()),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
