import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'korail_constants.dart';

/// 코레일 비밀번호 암호화 결과
class EncryptResult {
  /// 이중 Base64 인코딩된 암호화 비밀번호
  final String encryptedPw;

  /// 서버에서 받은 idx (로그인 요청 시 함께 전송)
  final String idx;

  const EncryptResult({required this.encryptedPw, required this.idx});
}

/// 코레일 비밀번호 암호화 서비스
///
/// 코레일 로그인 시 비밀번호를 AES-256-CBC로 암호화한다.
/// 1. 코레일 서버에서 암호화 키/idx를 획득
/// 2. AES-256-CBC로 비밀번호 암호화
/// 3. 이중 Base64 인코딩
class KorailCrypto {
  final Dio _dio;

  KorailCrypto(this._dio);

  /// 비밀번호를 암호화하여 반환
  Future<EncryptResult> encryptPassword(String password) async {
    // 1. 암호화 키 획득
    final response = await _dio.post(
      KorailConstants.codeUrl,
      data: {'code': 'app.login.cphd'},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    // 응답 파싱 (plain text → JSON)
    Map<String, dynamic> data;
    if (response.data is Map<String, dynamic>) {
      data = response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      data = json.decode(response.data as String) as Map<String, dynamic>;
    } else {
      throw Exception('암호화 키 응답 파싱 실패: ${response.data.runtimeType}');
    }

    // key/idx는 'app.login.cphd' 중첩 객체 안에 있음
    final cphd = data['app.login.cphd'] as Map<String, dynamic>?;
    if (cphd == null) {
      throw Exception('암호화 키 응답에 app.login.cphd 없음. keys=${data.keys.toList()}');
    }

    final key = cphd['key'] as String?;
    final idx = cphd['idx'] as String?;

    if (key == null || idx == null) {
      throw Exception('암호화 키 응답에 key/idx 없음. cphd keys=${cphd.keys.toList()}');
    }

    // ignore: avoid_print
    print('[KorailCrypto] 암호화 키 획득 성공 (idx: $idx, keyLen: ${key.length})');

    // 2. AES-256-CBC 암호화
    final keyBytes = Uint8List.fromList(utf8.encode(key));
    final iv = enc.IV(keyBytes.sublist(0, 16));
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );
    final encrypted = encrypter.encrypt(password, iv: iv);

    // 3. 이중 Base64 인코딩
    final doubleEncoded = base64Encode(utf8.encode(encrypted.base64));

    return EncryptResult(encryptedPw: doubleEncoded, idx: idx);
  }
}
