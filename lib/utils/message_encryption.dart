import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageEncryption {
  static final Random _random = Random.secure();
  static const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

  // 生成隨機金鑰
  static String generateKey(int length) {
    return String.fromCharCodes(
        Iterable.generate(
            length,
                (_) => _chars.codeUnitAt(_random.nextInt(_chars.length))
        )
    );
  }

  // 取得加密金鑰
  static Future<String> getEncryptionKey() async {
    // 嘗試從環境變數取得金鑰
    final envKey = dotenv.env['ENCRYPTION_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    // 如果沒有環境變數，嘗試從本地存儲取得
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString('encryption_key');

    // 如果本地存儲也沒有，生成一個新的金鑰並儲存
    if (key == null) {
      key = generateKey(32);
      await prefs.setString('encryption_key', key);
    }

    return key;
  }

  // 簡單的 XOR 加密
  static String encrypt(String text, String key) {
    if (text.isEmpty) return text;

    List<int> textBytes = utf8.encode(text);
    List<int> keyBytes = utf8.encode(key);
    List<int> encryptedBytes = [];

    for (int i = 0; i < textBytes.length; i++) {
      final keyChar = keyBytes[i % keyBytes.length];
      encryptedBytes.add(textBytes[i] ^ keyChar);
    }

    return base64.encode(encryptedBytes);
  }

  // 簡單的 XOR 解密
  static String decrypt(String encryptedText, String key) {
    if (encryptedText.isEmpty) return encryptedText;

    try {
      List<int> encryptedBytes = base64.decode(encryptedText);
      List<int> keyBytes = utf8.encode(key);
      List<int> decryptedBytes = [];

      for (int i = 0; i < encryptedBytes.length; i++) {
        final keyChar = keyBytes[i % keyBytes.length];
        decryptedBytes.add(encryptedBytes[i] ^ keyChar);
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      // 解密失敗，返回原始文字
      return '[無法解密的訊息]';
    }
  }

  // 使用 HMAC 計算訊息驗證碼
  static String generateHmac(String message, String key) {
    final keyBytes = utf8.encode(key);
    final messageBytes = utf8.encode(message);

    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(messageBytes);

    return digest.toString();
  }

  // 驗證 HMAC
  static bool verifyHmac(String message, String key, String expectedHmac) {
    final actualHmac = generateHmac(message, key);
    return actualHmac == expectedHmac;
  }
}