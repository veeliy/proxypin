import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';

/// PointyCastle加密服务
/// 使用AES-256-CBC加密算法
class EncryptionService {
  // 加密密钥（与Web端保持一致）
  static const String _encryptionKey = 'JsonEditorSecretKey2024!@#\$%^&*()';
  
  /// 加密JSON数据
  /// [jsonData] 要加密的JSON数据
  /// 返回包含加密内容和方法标识的Map
  static Map<String, dynamic> encryptJson(dynamic jsonData) {
    try {
      final String jsonString = json.encode(jsonData);
      print('正在使用PointyCastle加密Json数据，原文长度: ${jsonString.length}');
      
      // 生成随机IV (16字节)
      final SecureRandom random = SecureRandom('Fortuna');
      final Uint8List seed = Uint8List.fromList(
        List.generate(32, (i) => Random.secure().nextInt(256))
      );
      random.seed(KeyParameter(seed));
      final Uint8List iv = random.nextBytes(16);
      
      // 准备密钥（取前32字节作为AES-256密钥）
      final List<int> keyBytes = utf8.encode(_encryptionKey);
      final Uint8List key = Uint8List.fromList(keyBytes.take(32).toList().padded(32));
      
      // 创建AES-CBC加密器
      final CBCBlockCipher cipher = CBCBlockCipher(AESEngine());
      final ParametersWithIV<KeyParameter> params = ParametersWithIV(
        KeyParameter(key),
        iv,
      );
      
      // 初始化加密器
      cipher.init(true, params);
      
      // 准备明文数据并添加PKCS7填充
      final Uint8List plaintext = utf8.encode(jsonString);
      final Uint8List paddedPlaintext = _addPKCS7Padding(plaintext, 16);
      
      // 加密数据
      final Uint8List encrypted = _processBlocks(cipher, paddedPlaintext);
      
      // 组合IV和加密数据
      final Uint8List combined = Uint8List(iv.length + encrypted.length);
      combined.setRange(0, iv.length, iv);
      combined.setRange(iv.length, combined.length, encrypted);
      
      // Base64编码
      final String encryptedBase64 = base64.encode(combined);
      
      print('PointyCastle加密成功，加密后长度: ${encryptedBase64.length}');
      
      return {
        'content': encryptedBase64,
        'method': 'pointycastle',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (error) {
      print('PointyCastle加密失败: $error');
      throw Exception('加密失败: $error');
    }
  }
  
  /// 解密JSON数据
  /// [encryptedData] 加密的数据对象
  /// 返回解密后的JSON数据
  static dynamic decryptJson(dynamic encryptedData) {
    try {
      // 检查是否为加密格式
      if (encryptedData is! Map<String, dynamic> || !encryptedData.containsKey('content')) {
        print('数据未加密，直接返回');
        return encryptedData;
      }
      
      final String method = encryptedData['method'] ?? 'pointycastle';
      final String content = encryptedData['content'];
      
      if (method != 'pointycastle') {
        throw Exception('不支持的加密方法: $method');
      }
      
      print('正在使用PointyCastle解密数据...');
      
      // Base64解码
      final Uint8List combined = base64.decode(content);
      
      if (combined.length < 32) { // 至少需要16字节IV + 16字节数据
        throw Exception('加密数据格式无效：长度不足');
      }
      
      // 提取IV和加密数据
      final Uint8List iv = combined.sublist(0, 16);
      final Uint8List encrypted = combined.sublist(16);
      
      // 准备密钥
      final List<int> keyBytes = utf8.encode(_encryptionKey);
      final Uint8List key = Uint8List.fromList(keyBytes.take(32).toList().padded(32));
      
      // 创建AES-CBC解密器
      final CBCBlockCipher cipher = CBCBlockCipher(AESEngine());
      final ParametersWithIV<KeyParameter> params = ParametersWithIV(
        KeyParameter(key),
        iv,
      );
      
      // 初始化解密器
      cipher.init(false, params);
      
      // 解密数据
      final Uint8List decryptedPadded = _processBlocks(cipher, encrypted);
      
      // 移除PKCS7填充
      final Uint8List decrypted = _removePKCS7Padding(decryptedPadded);
      
      // 转换为字符串并解析JSON
      final String decryptedText = utf8.decode(decrypted);
      
      if (decryptedText.isEmpty) {
        throw Exception('解密结果为空');
      }
      
      print('PointyCastle解密成功，解密后长度: ${decryptedText.length}');
      return json.decode(decryptedText);
      
    } catch (error) {
      print('解密失败: $error');
      // 解密失败时返回原数据
      return encryptedData;
    }
  }
  
  /// 处理块加密/解密
  static Uint8List _processBlocks(BlockCipher cipher, Uint8List data) {
    final int blockSize = cipher.blockSize;
    final Uint8List output = Uint8List(data.length);
    
    for (int offset = 0; offset < data.length; offset += blockSize) {
      cipher.processBlock(data, offset, output, offset);
    }
    
    return output;
  }
  
  /// 添加PKCS7填充
  static Uint8List _addPKCS7Padding(Uint8List data, int blockSize) {
    final int paddingLength = blockSize - (data.length % blockSize);
    final Uint8List padded = Uint8List(data.length + paddingLength);
    
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = paddingLength;
    }
    
    return padded;
  }
  
  /// 移除PKCS7填充
  static Uint8List _removePKCS7Padding(Uint8List data) {
    if (data.isEmpty) {
      throw Exception('无法移除填充：数据为空');
    }
    
    final int paddingLength = data.last;
    
    if (paddingLength < 1 || paddingLength > 16 || paddingLength > data.length) {
      throw Exception('无效的PKCS7填充长度: $paddingLength');
    }
    
    // 验证填充字节
    for (int i = data.length - paddingLength; i < data.length; i++) {
      if (data[i] != paddingLength) {
        throw Exception('无效的PKCS7填充');
      }
    }
    
    return data.sublist(0, data.length - paddingLength);
  }
  
  /// 检查数据是否为加密格式
  static bool isEncrypted(dynamic data) {
    return data is Map<String, dynamic> && 
           data.containsKey('content') && 
           data.containsKey('method');
  }
}

/// 扩展List以支持padding
extension ListPadding on List<int> {
  List<int> padded(int length) {
    if (this.length >= length) return this;
    final List<int> result = List<int>.filled(length, 0);
    result.setRange(0, this.length, this);
    return result;
  }
}