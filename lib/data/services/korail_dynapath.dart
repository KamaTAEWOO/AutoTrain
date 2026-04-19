import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// 코레일 Dynapath 매크로 탐지 우회 엔진
///
/// 실제 KorailTalk 앱은 주요 엔드포인트 호출 시 `x-dynapath-m-token` 헤더와
/// `Sid` 파라미터를 동적으로 생성해 보낸다. 이 토큰이 없으면 코레일 서버는
/// `h_msg_cd=MACRO ERROR`로 로그인/예약 요청을 즉시 거부한다.
///
/// 포팅 출처: dhfhfk/korail2 (bypassDynapath 브랜치)
class KorailDynaPath {
  // ── Dynapath 보호 대상 엔드포인트 ──
  static const List<String> protectedPaths = [
    '/classes/com.korail.mobile.certification.TicketReservation',
    '/classes/com.korail.mobile.nonMember.NonMemTicket',
    '/classes/com.korail.mobile.seatMovie.ScheduleView',
    '/classes/com.korail.mobile.seatMovie.ScheduleViewSpecial',
    '/classes/com.korail.mobile.trn.prcFare.do',
    '/classes/com.korail.mobile.login.Login',
  ];

  // ── Dynapath 엔진 상수 ──
  static const String _appId = 'com.korail.talk';
  static const String _asValue = '%5B38ff229cb34c7dda8e28220a2d750cce%5D';
  static const String _deviceModel = 'SM-S928N';
  static const String _osType = 'Android';
  static const String _sdkVersion = 'v1';
  static const String _table =
      '3FE9jgRD4KdCyuawklqGJYmvfMn15P7US8XbxeLQtWT6OicBAopINs2Vh0HZrz';
  static const int _i8 = 161;
  static const int _i9 = 30;
  static const int _i10 = 2;

  // ── 디바이스 / 암호화 키 (KorailTalk 고정값) ──
  static const String deviceId = '558a4f02041657ea';
  static final Uint8List _sidKey =
      Uint8List.fromList(utf8.encode('2485dd54d9deaa36'));

  /// 엔진이 초기화된 시점의 밀리초 타임스탬프 (토큰의 `it` 필드로 사용)
  final String _appStartTs;

  final Random _random;

  KorailDynaPath._(this._appStartTs, this._random);

  factory KorailDynaPath() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return KorailDynaPath._(ts, Random.secure());
  }

  // ──────────────────────────────────────────
  // 공개 API
  // ──────────────────────────────────────────

  /// URL이 Dynapath 보호 대상인지 확인
  bool needsToken(String path) {
    for (final protected in protectedPaths) {
      if (path.contains(protected)) return true;
    }
    return false;
  }

  /// 요청 URL에 맞는 인증 헤더와 Sid를 생성.
  ///
  /// 보호 엔드포인트가 아닌 경우 빈 헤더와 null Sid 반환.
  ({Map<String, String> headers, String? sid}) buildAuth(String path) {
    if (!needsToken(path)) {
      return (headers: const <String, String>{}, sid: null);
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = _randomAlnum(4);
    final token = _generateToken(deviceId, ts, rand);
    final sid = _generateSid(ts);
    return (
      headers: {'x-dynapath-m-token': token},
      sid: sid,
    );
  }

  // ──────────────────────────────────────────
  // 토큰 생성
  // ──────────────────────────────────────────

  String _generateToken(String devId, int ts, String rand) {
    final plaintext = 'ai=$_appId&di=$devId&as=$_asValue&'
        'su=false&dbg=false&emu=false&hk=false&it=$_appStartTs&'
        'ts=$ts&rt=0&os=13&dm=$_deviceModel&st=$_osType&sv=$_sdkVersion';

    final dynKey = 'v1+$rand+$ts';
    final keyEnc = _encodeNormalBe(dynKey, _table);
    final bigKey = _makeKey(dynKey);
    final customTable = _makeEncodeTable(bigKey, _i9, _table);
    final bodyEnc = _encodeNormalBe(plaintext, customTable);

    return 'bEeEP${_table[keyEnc.length]}$keyEnc$bodyEnc';
  }

  /// Sid 생성: AES-CBC(Device + ts)를 base64 → 끝에 "\n" 추가
  ///
  /// Device 문자열은 'AD' 고정 (Korail Android 클라이언트 식별자).
  String _generateSid(int ts) {
    final plaintext = utf8.encode('AD$ts');
    final padded = _pkcs7Pad(plaintext, 16);

    final key = enc.Key(_sidKey);
    final iv = enc.IV(_sidKey);
    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.cbc, padding: null),
    );
    final encrypted = encrypter.encryptBytes(padded, iv: iv);
    return '${base64Encode(encrypted.bytes)}\n';
  }

  // ──────────────────────────────────────────
  // 인코딩 알고리즘 (Python → Dart 1:1 포팅)
  // ──────────────────────────────────────────

  /// 문자열을 Korail 앱 전용 바이트 시퀀스로 변환
  List<int> _string2xA1s(String dataStr) {
    final result = <int>[];
    for (var i = 0; i < dataStr.length; i++) {
      final cp = dataStr.codeUnitAt(i);
      if (cp < 128) {
        result.add(cp);
      } else if (cp < 2048) {
        result.add(128 | ((cp >> 7) & 15));
        result.add(cp & 127);
      } else if (cp >= 262144) {
        result.add(160);
        result.add((cp >> 14) & 127);
        result.add((cp >> 7) & 127);
        result.add(cp & 127);
      } else if ((63488 & cp) != 55296) {
        result.add(((cp >> 14) & 15) | 144);
        result.add((cp >> 7) & 127);
        result.add(cp & 127);
      }
    }
    return result;
  }

  /// i8진법 → i9진법 인코딩
  String _encodeNormalBe(String dataStr, String table,
      {int i8 = _i8, int i9 = _i9, int i10 = _i10}) {
    final listData = _string2xA1s(dataStr);
    final sb = StringBuffer();
    final iArr = List<int>.filled(i10 + 1, 0);
    var idx = 0;
    var size = listData.length % i10;
    final size2 = listData.length - size;

    while (idx < size2) {
      var val = 0;
      for (var k = 0; k < i10; k++) {
        val = (val * i8) + listData[idx];
        idx++;
      }
      for (var i = 0; i < i10 + 1; i++) {
        iArr[i] = val % i9;
        val ~/= i9;
      }
      for (var i = i10; i >= 0; i--) {
        sb.write(table[iArr[i]]);
      }
    }

    if (size > 0) {
      var val = 0;
      for (var k = 0; k < size; k++) {
        val = (val * i8) + listData[idx];
        idx++;
      }
      for (var i = 0; i < size + 1; i++) {
        iArr[i] = val % i9;
        val ~/= i9;
      }
      while (size >= 0) {
        sb.write(table[iArr[size]]);
        size--;
      }
    }

    return sb.toString();
  }

  /// 동적 키 → BigInt 변환
  BigInt _makeKey(String keyStr) {
    var bigIntAdd = BigInt.zero;
    for (var k = 0; k < keyStr.length; k++) {
      final cp = keyStr.codeUnitAt(k);
      var i9Bit = 32768;
      for (var i = 0; i < 16; i++) {
        if ((i9Bit & cp) != 0) break;
        i9Bit >>= 1;
      }
      bigIntAdd = bigIntAdd * BigInt.from(i9Bit << 1) + BigInt.from(cp);
    }
    return bigIntAdd;
  }

  /// BigInt → 커스텀 인코딩 테이블 생성
  String _makeEncodeTable(BigInt num, int encodeSize, String baseTable) {
    final sb = StringBuffer();
    var tempNum = num;
    for (var i = 0; i < encodeSize; i++) {
      final j8Divisor = encodeSize - i;
      final divisor = BigInt.from(j8Divisor);
      final remainder = (tempNum % divisor).toInt();
      final char = _internalI(baseTable, remainder, sb.toString());
      sb.write(char);
      tempNum = tempNum ~/ divisor;
    }
    return sb.toString();
  }

  /// 이미 사용된 문자를 제외하고 baseTable에서 remainder 번째 남은 문자 반환
  String _internalI(String baseTable, int remainder, String currentSb) {
    var j8Count = 0;
    for (var k = 0; k < baseTable.length; k++) {
      final char = baseTable[k];
      if (!currentSb.contains(char)) {
        if (j8Count == remainder) return char;
        j8Count++;
      }
    }
    return ' ';
  }

  // ──────────────────────────────────────────
  // 헬퍼
  // ──────────────────────────────────────────

  /// A-Z, 0-9 중 length자리 무작위 문자열
  String _randomAlnum(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[_random.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  /// PKCS7 수동 패딩 (encrypt 패키지의 padding='PKCS7'와 동일한 로직)
  Uint8List _pkcs7Pad(List<int> data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLen);
    padded.setRange(0, data.length, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    return padded;
  }
}
