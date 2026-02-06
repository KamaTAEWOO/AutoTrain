import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/api_error.dart';
import '../models/reservation.dart';
import '../models/srt_train.dart';
import '../models/train.dart';
import 'srt_constants.dart';
import 'srt_netfunnel.dart';
import 'train_api_service.dart';

/// SRT 서버와 직접 통신하는 API 클라이언트
///
/// Python SRTrain 라이브러리 기반으로 구현.
/// 비밀번호는 평문 전송 (SRT 서버 사양).
class SrtApi implements TrainApiService {
  static SrtApi? _instance;

  late final Dio _dio;
  late final CookieJar _cookieJar;

  /// 로그인한 사용자 이름
  String? _userName;

  /// 로그인한 멤버 번호
  String? _memberNo;

  /// 세션 유지 여부
  bool _hasSession = false;

  /// 예약용 열차 캐시 (cacheKey → SrtTrain)
  final Map<String, SrtTrain> _trainCache = {};

  /// NetFunnel 대기열 관리
  final SrtNetFunnel _netFunnel = SrtNetFunnel();

  SrtApi._() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        baseUrl: SrtConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': SrtConstants.userAgent,
          'Accept': 'application/json',
        },
        responseType: ResponseType.plain,
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _log('← ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          _log('✗ ${error.type} ${error.response?.statusCode} '
              '${error.requestOptions.uri}: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// 싱글톤 인스턴스
  static SrtApi get instance {
    _instance ??= SrtApi._();
    return _instance!;
  }

  @override
  bool get hasSession => _hasSession;

  @override
  String? get userName => _userName;

  // ──────────────────────────────────────────
  // 로그인
  // ──────────────────────────────────────────

  @override
  Future<({String sessionKey, String userName})> login(
    String id,
    String pw,
  ) async {
    try {
      _log('SRT 로그인 시작: ${id.replaceRange(3, id.length - 2, '***')}');

      // 기존 세션 정리 (중복 로그인 방지)
      // 서버에 로그아웃 요청 후 쿠키 삭제
      try {
        await _dio.post(
          SrtConstants.logoutUrl,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        _log('SRT 사전 로그아웃 완료');
      } catch (_) {
        _log('SRT 사전 로그아웃 스킵 (세션 없음)');
      }
      _hasSession = false;
      _userName = null;
      _memberNo = null;
      await _cookieJar.deleteAll();

      // 로그인 유형 판별
      final inputFlg = _detectInputType(id);
      // 전화번호인 경우 하이픈 등 특수문자 제거
      final cleanId = inputFlg == '3'
          ? id.replaceAll(RegExp(r'[^0-9]'), '')
          : id;

      final response = await _dio.post(
        SrtConstants.loginUrl,
        data: {
          'auto': 'Y',
          'check': 'Y',
          'page': 'menu',
          'deviceKey': '-',
          'customerYn': '',
          'login_referer': '${SrtConstants.baseUrl}${SrtConstants.mainUrl}',
          'srchDvCd': inputFlg,
          'srchDvNm': cleanId,
          'hmpgPwdCphd': pw,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);
      final userMap = data['userMap'] as Map<String, dynamic>? ?? {};

      // 실패 응답: 최상위에 strResult=FAIL + MSG
      // 성공 응답: strResult 없음, userMap.RTNCD=Y + userMap.MB_CRD_NO
      final topResult = data['strResult'] as String? ?? '';
      final topMsg = data['MSG'] as String? ?? '';
      final rtnCd = userMap['RTNCD'] as String? ?? '';

      if (topResult == 'FAIL') {
        _log('SRT 로그인 실패: $topMsg');
        throw ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: topMsg.isNotEmpty ? topMsg : 'SRT 로그인에 실패했습니다',
        );
      }

      _userName = userMap['CUST_NM'] as String? ?? '';
      _memberNo = userMap['MB_CRD_NO'] as String? ?? '';

      // 성공 확인: RTNCD=Y 이고 MB_CRD_NO 존재
      if (rtnCd != 'Y' || _memberNo!.isEmpty) {
        _hasSession = false;
        final msg = userMap['MSG'] as String? ?? topMsg;
        _log('SRT 로그인 실패: RTNCD=$rtnCd, MB_CRD_NO=$_memberNo');
        throw ApiError(
          error: 'SERVER_ERROR',
          code: 'SYSTEM_001',
          detail: msg.isNotEmpty ? msg : '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
        );
      }

      _hasSession = true;

      _log('SRT 로그인 성공: $_userName');

      return (sessionKey: _memberNo!, userName: _userName!);
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      _log('SRT 로그인 DioException: ${e.type} ${e.message}');
      throw _handleDioError(e);
    } catch (e) {
      _log('SRT 로그인 예외: $e');
      throw NetworkError('SRT 로그인 중 오류: $e');
    }
  }

  // ──────────────────────────────────────────
  // 열차 조회
  // ──────────────────────────────────────────

  @override
  Future<List<Train>> searchTrains(
    String dep,
    String arr,
    String date,
    String time,
  ) async {
    _requireSession();

    _trainCache.clear();
    final allTrains = <Train>[];
    final seenTrainKeys = <String>{};
    var currentTime = time;

    try {
      for (var i = 0; i < 15; i++) {
        final trains = await _searchTrainsSingle(dep, arr, date, currentTime);

        if (trains.isEmpty) break;

        for (final train in trains) {
          final key = '${train.trainNo}_${train.depTime}';
          if (!seenTrainKeys.contains(key)) {
            seenTrainKeys.add(key);
            allTrains.add(train);
          }
        }

        final lastTrain = trains.last;
        final lastDepTime = lastTrain.depTime.replaceAll(':', '');

        if (lastDepTime.startsWith('23') &&
            int.parse(lastDepTime.substring(2, 4)) >= 59) {
          break;
        }

        currentTime = _addOneMinute(lastDepTime);
        _log('다음 검색 시간: $currentTime (반복 ${i + 1}/15)');
      }

      _log('SRT 전체 열차 조회 완료: ${allTrains.length}개');
      return allTrains;
    } on ApiError {
      if (allTrains.isNotEmpty) {
        _log('SRT 전체 열차 조회 완료 (중단): ${allTrains.length}개');
        return allTrains;
      }
      rethrow;
    }
  }

  /// 단일 열차 조회
  Future<List<Train>> _searchTrainsSingle(
    String dep,
    String arr,
    String date,
    String time,
  ) async {
    try {
      final depCode = SrtConstants.stationCode(dep);
      final arrCode = SrtConstants.stationCode(arr);

      if (depCode.isEmpty || arrCode.isEmpty) {
        throw ApiError(
          error: 'INVALID_STATION',
          code: 'SEARCH_001',
          detail: '역 코드를 찾을 수 없습니다: $dep($depCode) → $arr($arrCode)',
        );
      }

      // NetFunnel 키 발급
      final nfKey = await _netFunnel.generateKey();

      final response = await _dio.post(
        SrtConstants.searchUrl,
        data: {
          'chtnDvCd': '1',
          'arriveTime': 'N',
          'seatAttCd': '015',
          'psgNum': '1',
          'trnGpCd': SrtConstants.trainGroupSrt,
          'stlbTrnClsfCd': SrtConstants.trainClassSrt,
          'dptDt': date,
          'dptTm': time,
          'dptRsStnCd': depCode,
          'arvRsStnCd': arrCode,
          'netfunnelKey': nfKey,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);

      // resultMap이 배열인 경우 (열차 조회 응답)
      final resultMapRaw = data['resultMap'];
      final Map<String, dynamic> statusMap;
      if (resultMapRaw is List && resultMapRaw.isNotEmpty) {
        statusMap = resultMapRaw[0] as Map<String, dynamic>;
      } else {
        statusMap = data;
      }
      final result = statusMap['strResult'] as String? ?? '';
      final msgTxt = statusMap['msgTxt'] as String? ??
          statusMap['MSG'] as String? ??
          data['MSG'] as String? ?? '';
      final msgCd = statusMap['msgCd'] as String? ?? '';

      if (result == 'FAIL') {
        // NetFunnel 키 만료 시 재발급 후 재시도
        if (msgCd == 'NET000001') {
          _netFunnel.invalidate();
          _log('NetFunnel key invalid, retrying...');
          return _searchTrainsSingle(dep, arr, date, time);
        }
        if (msgTxt.contains('조회 결과가 없습니다') || msgTxt.contains('운행하는 열차가 없습니다')) {
          return [];
        }
        if (msgTxt.contains('로그인')) {
          _hasSession = false;
          throw ApiError(
            error: 'SESSION_EXPIRED',
            code: 'AUTH_003',
            detail: msgTxt,
          );
        }
        throw ApiError(
          error: 'SRT_SERVER_ERROR',
          code: 'SYSTEM_002',
          detail: msgTxt.isEmpty ? '열차 조회에 실패했습니다' : msgTxt,
        );
      }

      // 열차 목록 파싱
      final outDataSets = data['outDataSets'] as Map<String, dynamic>? ?? {};
      final dsOutput1 = outDataSets['dsOutput1'] as List? ?? [];

      if (dsOutput1.isEmpty) return [];

      final trains = <Train>[];
      for (final item in dsOutput1) {
        final map = item as Map<String, dynamic>;
        final st = SrtTrain.fromJson(map);
        _trainCache[st.cacheKey] = st;
        trains.add(st.toTrain());
        _log('  SRT ${st.trainNo} ${st.depTimeFormatted}→${st.arrTimeFormatted} '
            '일반=${st.generalSeatCode}(${st.hasGeneralSeats}) '
            '특실=${st.specialSeatCode}(${st.hasSpecialSeats})');
      }

      return trains;
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  String _addOneMinute(String time) {
    final padded = time.padRight(6, '0');
    var hour = int.parse(padded.substring(0, 2));
    var minute = int.parse(padded.substring(2, 4));

    minute += 1;
    if (minute >= 60) {
      minute = 0;
      hour += 1;
    }
    if (hour >= 24) {
      hour = 23;
      minute = 59;
    }

    return '${hour.toString().padLeft(2, '0')}'
        '${minute.toString().padLeft(2, '0')}00';
  }

  // ──────────────────────────────────────────
  // 예약
  // ──────────────────────────────────────────

  @override
  Future<Reservation> reserve(
    String trainNo,
    String seatType, {
    required String depStation,
    required String arrStation,
    required String date,
    String time = '000000',
  }) async {
    _requireSession();

    try {
      final st = _findCachedTrain(trainNo, time);
      if (st == null) {
        throw const ApiError(
          error: 'NO_TRAINS',
          code: 'SEARCH_002',
          detail: '열차 정보를 찾을 수 없습니다. 다시 조회해 주세요.',
        );
      }

      // 좌석 클래스: '1'(일반), '2'(특실)
      final psrmClCd = seatType == 'special' ? '2' : '1';
      // 열차번호 5자리 패딩
      final paddedTrainNo = st.trainNo.padLeft(5, '0');

      _log('SRT 예약 요청: trainNo=$paddedTrainNo, depDate=${st.depDate}');

      // NetFunnel 키 발급
      final nfKey = await _netFunnel.generateKey();

      final response = await _dio.post(
        SrtConstants.reserveUrl,
        data: {
          // 예약 타입
          'jobId': '1101',           // 개인 예약
          'jrnyCnt': '1',
          'jrnyTpCd': '11',
          'jrnySqno1': '001',
          'stndFlg': 'N',
          // 열차 정보 (suffix "1")
          'trnGpCd1': st.trainGroup,           // '300'
          'trnGpCd': '109',                    // 고정값
          'grpDv': '0',
          'rtnDv': '0',
          'stlbTrnClsfCd1': st.trainClassCode, // '17' for SRT
          'dptRsStnCd1': st.depStationCode,
          'dptRsStnCdNm1': st.depStationName,
          'arvRsStnCd1': st.arrStationCode,
          'arvRsStnCdNm1': st.arrStationName,
          'dptDt1': st.depDate,
          'dptTm1': st.depTime,
          'arvTm1': st.arrTime,
          'trnNo1': paddedTrainNo,
          'runDt1': st.runDate,
          'dptStnConsOrdr1': st.depStationConsOrdr,
          'arvStnConsOrdr1': st.arrStationConsOrdr,
          'dptStnRunOrdr1': st.depStationRunOrdr,
          'arvStnRunOrdr1': st.arrStationRunOrdr,
          // 승객 정보 (1명, 일반 성인)
          'totPrnb': '1',
          'psgGridcnt': '1',
          'psgTpCd1': '1',          // 성인
          'psgInfoPerPrnb1': '1',   // 1명
          'locSeatAttCd1': '000',   // 좌석 위치 무관
          'rqSeatAttCd1': '015',    // 일반 좌석
          'dirSeatAttCd1': '009',   // 방향 무관
          'smkSeatAttCd1': '000',
          'etcSeatAttCd1': '000',
          'psrmClCd1': psrmClCd,
          // 예약 유형
          'reserveType': '11',
          // NetFunnel 키
          'netfunnelKey': nfKey,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);

      // resultMap은 배열 형태
      final resultMapRaw = data['resultMap'];
      final Map<String, dynamic> statusMap;
      if (resultMapRaw is List && resultMapRaw.isNotEmpty) {
        statusMap = resultMapRaw[0] as Map<String, dynamic>;
      } else {
        statusMap = data;
      }
      final result = statusMap['strResult'] as String? ?? '';
      final msgTxt = statusMap['msgTxt'] as String? ??
          statusMap['MSG'] as String? ??
          data['MSG'] as String? ?? '';
      final msgCd = statusMap['msgCd'] as String? ?? '';

      if (result == 'FAIL') {
        // NetFunnel 키 만료
        if (msgCd == 'NET000001') {
          _netFunnel.invalidate();
          _log('NetFunnel key invalid for reserve, retrying...');
          return reserve(trainNo, seatType,
              depStation: depStation, arrStation: arrStation,
              date: date, time: time);
        }

        final msg = msgTxt.isNotEmpty ? msgTxt : '예약에 실패했습니다';

        if (msg.contains('매진') || msg.contains('잔여석 없음')) {
          throw ApiError(
            error: 'SOLD_OUT',
            code: 'RESERVE_001',
            detail: msg,
          );
        }

        throw ApiError(
          error: 'RESERVATION_FAILED',
          code: 'RESERVE_002',
          detail: msg,
        );
      }

      // 예약번호: reservListMap[0].pnrNo
      final reservListMap = data['reservListMap'] as List? ?? [];
      final pnrNo = reservListMap.isNotEmpty
          ? (reservListMap[0] as Map<String, dynamic>)['pnrNo'] as String? ?? ''
          : '';

      _log('SRT 예약 성공: pnrNo=$pnrNo');

      return Reservation(
        reservationId: pnrNo,
        status: 'success',
        train: st.toTrain(),
        message: '예약이 완료되었습니다',
        reservedAt: DateTime.now(),
      );
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ──────────────────────────────────────────
  // 예약 목록
  // ──────────────────────────────────────────

  @override
  Future<List<Reservation>> fetchReservations() async {
    _requireSession();

    try {
      final response = await _dio.post(
        SrtConstants.reservationListUrl,
        data: {'pageNo': '0'},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);

      // resultMap은 배열 형태
      final resultMapRaw = data['resultMap'];
      final Map<String, dynamic> statusMap;
      if (resultMapRaw is List && resultMapRaw.isNotEmpty) {
        statusMap = resultMapRaw[0] as Map<String, dynamic>;
      } else {
        statusMap = data;
      }
      final result = statusMap['strResult'] as String? ?? '';
      final msgTxt = statusMap['msgTxt'] as String? ??
          statusMap['MSG'] as String? ??
          data['MSG'] as String? ?? '';

      if (result == 'FAIL') {
        if (msgTxt.contains('내역이 없습니다') ||
            msgTxt.contains('조회 결과가 없습니다') ||
            msgTxt.contains('예약 내역')) {
          return [];
        }
        if (msgTxt.contains('로그인')) {
          _hasSession = false;
          throw ApiError(
            error: 'SESSION_EXPIRED',
            code: 'AUTH_003',
            detail: msgTxt,
          );
        }
        return [];
      }

      // trainListMap: 예약 기본 정보, payListMap: 결제/열차 상세 정보
      final trainListMap = data['trainListMap'] as List? ?? [];
      final payListMap = data['payListMap'] as List? ?? [];

      final reservations = <Reservation>[];
      for (var i = 0; i < trainListMap.length; i++) {
        final trainInfo = trainListMap[i] as Map<String, dynamic>;
        final payInfo = i < payListMap.length
            ? payListMap[i] as Map<String, dynamic>
            : <String, dynamic>{};

        final pnrNo = trainInfo['pnrNo'] as String? ?? '';
        final stlFlg = payInfo['stlFlg'] as String? ?? 'N';

        final train = Train(
          trainNo: (payInfo['trnNo'] as String? ?? '').trim(),
          trainType: 'SRT',
          depStation: SrtConstants.stationName(
              payInfo['dptRsStnCd'] as String? ?? ''),
          arrStation: SrtConstants.stationName(
              payInfo['arvRsStnCd'] as String? ?? ''),
          depTime: _formatTime(payInfo['dptTm'] as String? ?? ''),
          arrTime: _formatTime(payInfo['arvTm'] as String? ?? ''),
        );

        reservations.add(Reservation(
          reservationId: pnrNo,
          status: stlFlg == 'Y' ? 'paid' : 'success',
          train: train,
          message: stlFlg == 'Y' ? '결제 완료' : '미결제',
          reservedAt: DateTime.now(),
        ));
      }

      _log('SRT 예약 목록 조회: ${reservations.length}건');
      return reservations;
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ──────────────────────────────────────────
  // 예약 취소
  // ──────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    _requireSession();

    try {
      _log('SRT 예약 취소 요청: pnrNo=$reservationId');

      final response = await _dio.post(
        SrtConstants.cancelUrl,
        data: {
          'pnrNo': reservationId,
          'jrnyCnt': '1',
          'rsvChgTno': '0',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);

      // resultMap은 배열 형태
      final resultMapRaw = data['resultMap'];
      final Map<String, dynamic> statusMap;
      if (resultMapRaw is List && resultMapRaw.isNotEmpty) {
        statusMap = resultMapRaw[0] as Map<String, dynamic>;
      } else {
        statusMap = data;
      }
      final result = statusMap['strResult'] as String? ?? '';
      final msgTxt = statusMap['msgTxt'] as String? ??
          statusMap['MSG'] as String? ??
          data['MSG'] as String? ?? '';

      if (result == 'FAIL') {
        throw ApiError(
          error: 'CANCEL_FAILED',
          code: 'RESERVE_003',
          detail: msgTxt.isNotEmpty ? msgTxt : '취소에 실패했습니다',
        );
      }

      _log('SRT 예약 취소 성공: pnrNo=$reservationId');

      return {
        'message': '예약이 취소되었습니다',
      };
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ──────────────────────────────────────────
  // 로그아웃
  // ──────────────────────────────────────────

  @override
  void logout() {
    // 서버에 로그아웃 요청 (fire-and-forget)
    if (_hasSession) {
      _dio.post(SrtConstants.logoutUrl).ignore();
    }
    _hasSession = false;
    _userName = null;
    _memberNo = null;
    _trainCache.clear();
    _cookieJar.deleteAll();
    _log('SRT 로그아웃 완료');
  }

  // ──────────────────────────────────────────
  // 내부 헬퍼
  // ──────────────────────────────────────────

  Map<String, dynamic> _parseJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final parsed = json.decode(data);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (e) {
        _log('JSON 파싱 실패: $e');
      }
    }
    throw const ApiError(
      error: 'SRT_SERVER_ERROR',
      code: 'SYSTEM_002',
      detail: 'SRT 서버 응답을 처리할 수 없습니다',
    );
  }

  void _requireSession() {
    if (!_hasSession) {
      throw const ApiError(
        error: 'SESSION_EXPIRED',
        code: 'AUTH_003',
        detail: '로그인이 필요합니다',
      );
    }
  }

  /// 로그인 ID 유형 판별
  String _detectInputType(String id) {
    if (id.contains('@')) return '2'; // 이메일
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    // 01X로 시작하는 10~11자리 → 전화번호
    if (RegExp(r'^01\d{8,9}$').hasMatch(digits)) return '3';
    // 그 외 숫자 → 회원번호
    if (RegExp(r'^\d{10,}$').hasMatch(digits)) return '1';
    return '3'; // 기본: 전화번호
  }

  SrtTrain? _findCachedTrain(String trainNo, String time) {
    final trimmedNo = trainNo.trim();
    for (final entry in _trainCache.entries) {
      if (entry.value.trainNo.trim() == trimmedNo) {
        return entry.value;
      }
    }
    return null;
  }

  String _formatTime(String raw) {
    if (raw.length >= 4) {
      return '${raw.substring(0, 2)}:${raw.substring(2, 4)}';
    }
    return raw;
  }

  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkError('SRT 서버 연결 시간이 초과되었습니다');
      case DioExceptionType.receiveTimeout:
        return const NetworkError('SRT 서버 응답 대기 시간이 초과되었습니다');
      case DioExceptionType.connectionError:
        return NetworkError('SRT 서버에 연결할 수 없습니다: ${e.error}');
      default:
        return NetworkError(e.message ?? '네트워크 오류가 발생했습니다');
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[SrtApi] $message');
    dev.log(message, name: 'SrtApi');
  }
}
