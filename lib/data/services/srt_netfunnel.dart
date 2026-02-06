import 'dart:developer' as dev;

import 'package:dio/dio.dart';

/// SRT NetFunnel 대기열 관리
///
/// 열차 조회/예약 등 주요 API 호출 전 NetFunnel 키를 발급받아야 한다.
class SrtNetFunnel {
  static const _netfunnelUrl = 'http://nf.letskorail.com/ts.wseq';
  static const _referer = 'https://app.srail.or.kr:443';

  static const _opGetKey = '5101';
  static const _opSetComplete = '5004';

  final Dio _dio;

  /// 캐시된 키
  String? _cachedKey;

  SrtNetFunnel()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            responseType: ResponseType.plain,
          ),
        );

  /// NetFunnel 키 발급 (캐시 사용)
  Future<String> generateKey({bool useCache = true}) async {
    if (useCache && _cachedKey != null) return _cachedKey!;

    final key = await _getKey();
    await _setComplete(key);
    _cachedKey = key;
    return key;
  }

  /// 캐시 무효화
  void invalidate() {
    _cachedKey = null;
  }

  Future<String> _getKey() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final response = await _dio.get(
      _netfunnelUrl,
      queryParameters: {
        'opcode': _opGetKey,
        'nfid': '0',
        'prefix': 'NetFunnel.gRtype=$_opGetKey;',
        'sid': 'service_1',
        'aid': 'act_10',
        'js': 'true',
        '$ts': '',
      },
      options: Options(headers: {'Referer': _referer}),
    );

    final text = response.data as String;
    final match = RegExp(r'key=([^&]+)').firstMatch(text);
    if (match == null) {
      _log('NetFunnel key not found: $text');
      return '';
    }

    final key = match.group(1)!;
    _log('NetFunnel key acquired: ${key.substring(0, 30)}...');
    return key;
  }

  Future<void> _setComplete(String key) async {
    if (key.isEmpty) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    try {
      await _dio.get(
        _netfunnelUrl,
        queryParameters: {
          'opcode': _opSetComplete,
          'key': key,
          'nfid': '0',
          'prefix': 'NetFunnel.gRtype=$_opSetComplete;',
          'js': 'true',
          '$ts': '',
        },
        options: Options(headers: {'Referer': _referer}),
      );
    } catch (_) {
      // setComplete 실패는 무시
    }
  }

  void _log(String msg) {
    dev.log(msg, name: 'SrtNetFunnel');
  }
}
