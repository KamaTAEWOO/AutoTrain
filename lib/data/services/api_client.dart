import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_config.dart';
import '../../core/constants/rail_type.dart';

/// 재로그인에 필요한 자격 증명 저장용 콜백 타입
typedef ReLoginCallback = Future<String?> Function();

/// Dio HTTP 클라이언트 싱글톤
///
/// Backend API와의 모든 HTTP 통신을 담당한다.
/// - 세션 토큰(Bearer) 자동 첨부
/// - 401 응답 시 자동 재로그인 시도
/// - 요청/응답 로깅
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  /// 암호화된 자격 증명 저장소
  static const _secureStorage = FlutterSecureStorage();

  // KTX 키
  static const _keyKorailId = 'korail_id';
  static const _keyKorailPw = 'korail_pw';
  static const _keyAutoLogin = 'auto_login';

  // SRT 키
  static const _keySrtId = 'srt_id';
  static const _keySrtPw = 'srt_pw';
  static const _keySrtAutoLogin = 'srt_auto_login';

  // 마지막 사용 철도 타입
  static const _keyLastRailType = 'last_rail_type';

  /// 재로그인 진행 중 플래그 (중복 방지)
  bool _isReLogging = false;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout:
            const Duration(seconds: ApiConfig.connectTimeoutSeconds),
        receiveTimeout:
            const Duration(seconds: ApiConfig.receiveTimeoutSeconds),
        headers: {
          'Content-Type': ApiConfig.contentType,
          'Accept': ApiConfig.contentType,
        },
      ),
    );

    // 로깅 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          developer.log(
            '${options.method} ${options.path}',
            name: 'API',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            '${response.statusCode} ${response.requestOptions.path}',
            name: 'API',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          developer.log(
            '${error.response?.statusCode} '
            '${error.requestOptions.path}: ${error.message}',
            name: 'API',
            level: 900,
          );
          handler.next(error);
        },
      ),
    );

    // 401 자동 재로그인 인터셉터
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isReLogging) {
            // 로그인 요청 자체의 401은 재시도하지 않음
            if (error.requestOptions.path == ApiConfig.loginPath) {
              handler.next(error);
              return;
            }

            // 암호화 저장소에서 자격 증명 읽기
            final savedId = await _secureStorage.read(key: _keyKorailId);
            final savedPw = await _secureStorage.read(key: _keyKorailPw);

            if (savedId == null || savedPw == null) {
              handler.next(error);
              return;
            }

            _isReLogging = true;
            try {
              // 재로그인 시도
              final response = await _dio.post(
                ApiConfig.loginPath,
                data: {
                  'korail_id': savedId,
                  'korail_pw': savedPw,
                },
              );

              final data = response.data as Map<String, dynamic>;
              final newToken = data['session_token'] as String;
              setSessionToken(newToken);

              // 원래 요청 재시도
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(opts);
              handler.resolve(retryResponse);
            } on DioException {
              // 재로그인 실패 시 원래 에러 전달
              handler.next(error);
            } finally {
              _isReLogging = false;
            }
          } else {
            handler.next(error);
          }
        },
      ),
    );
  }

  /// 싱글톤 인스턴스
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  /// Dio 인스턴스 접근자
  Dio get dio => _dio;

  /// 세션 토큰 설정
  void setSessionToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 세션 토큰 제거
  void clearSessionToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// 자격 증명을 암호화하여 안전한 저장소에 보관 (자동 재로그인용)
  Future<void> saveCredentials(
    String id,
    String pw, {
    RailType railType = RailType.ktx,
  }) async {
    final idKey = railType == RailType.ktx ? _keyKorailId : _keySrtId;
    final pwKey = railType == RailType.ktx ? _keyKorailPw : _keySrtPw;
    await _secureStorage.write(key: idKey, value: id);
    await _secureStorage.write(key: pwKey, value: pw);
  }

  /// 저장된 자격 증명 제거
  Future<void> clearCredentials({RailType railType = RailType.ktx}) async {
    final idKey = railType == RailType.ktx ? _keyKorailId : _keySrtId;
    final pwKey = railType == RailType.ktx ? _keyKorailPw : _keySrtPw;
    final autoKey = railType == RailType.ktx ? _keyAutoLogin : _keySrtAutoLogin;
    await _secureStorage.delete(key: idKey);
    await _secureStorage.delete(key: pwKey);
    await _secureStorage.delete(key: autoKey);
  }

  /// 자동 로그인 설정 저장
  Future<void> saveAutoLoginSetting(
    bool enabled, {
    RailType railType = RailType.ktx,
  }) async {
    final key = railType == RailType.ktx ? _keyAutoLogin : _keySrtAutoLogin;
    await _secureStorage.write(key: key, value: enabled.toString());
  }

  /// 자동 로그인 설정 읽기 (기본값: true)
  Future<bool> readAutoLoginSetting({
    RailType railType = RailType.ktx,
  }) async {
    final key = railType == RailType.ktx ? _keyAutoLogin : _keySrtAutoLogin;
    final value = await _secureStorage.read(key: key);
    if (value == null) return true;
    return value == 'true';
  }

  /// 세션 토큰이 설정되어 있는지 확인
  bool get hasSessionToken =>
      _dio.options.headers.containsKey('Authorization');

  /// 저장된 자격 증명이 있는지 확인하고 반환
  Future<({String id, String pw})?> readSavedCredentials({
    RailType railType = RailType.ktx,
  }) async {
    final idKey = railType == RailType.ktx ? _keyKorailId : _keySrtId;
    final pwKey = railType == RailType.ktx ? _keyKorailPw : _keySrtPw;
    final savedId = await _secureStorage.read(key: idKey);
    final savedPw = await _secureStorage.read(key: pwKey);
    if (savedId != null && savedPw != null) {
      return (id: savedId, pw: savedPw);
    }
    return null;
  }

  /// 마지막 사용 철도 타입 저장
  Future<void> saveLastRailType(RailType railType) async {
    await _secureStorage.write(key: _keyLastRailType, value: railType.name);
  }

  /// 마지막 사용 철도 타입 읽기 (기본값: ktx)
  Future<RailType> readLastRailType() async {
    final value = await _secureStorage.read(key: _keyLastRailType);
    if (value == 'srt') return RailType.srt;
    return RailType.ktx;
  }
}
