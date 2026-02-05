import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/api_error.dart';
import '../models/korail_train.dart';
import '../models/reservation.dart';
import '../models/train.dart';
import 'korail_constants.dart';
import 'korail_crypto.dart';

/// 코레일 서버와 직접 통신하는 API 클라이언트
///
/// Python 백엔드 없이 코레일 모바일 API를 직접 호출한다.
class KorailApi {
  static KorailApi? _instance;

  late final Dio _dio;
  late final CookieJar _cookieJar;
  late final KorailCrypto _crypto;

  /// 코레일 세션 키 (로그인 후 설정)
  String? _sessionKey;

  /// 로그인한 사용자 이름
  String? _userName;

  /// 예약용 열차 캐시 (cacheKey → KorailTrain)
  final Map<String, KorailTrain> _trainCache = {};

  /// 예약 취소용 메타데이터 캐시 (reservationId → metadata)
  final Map<String, Map<String, String>> _reservationMeta = {};

  KorailApi._() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        baseUrl: KorailConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent': KorailConstants.userAgent,
        },
        // 코레일 서버는 JSON이지만 content-type이 부정확할 수 있으므로 plain으로 수신
        responseType: ResponseType.plain,
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));

    // 로깅 인터셉터
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

    _crypto = KorailCrypto(_dio);
  }

  /// 싱글톤 인스턴스
  static KorailApi get instance {
    _instance ??= KorailApi._();
    return _instance!;
  }

  /// 세션이 활성 상태인지 확인
  bool get hasSession => _sessionKey != null;

  /// 로그인한 사용자 이름
  String? get userName => _userName;

  // ──────────────────────────────────────────
  // 로그인
  // ──────────────────────────────────────────

  /// 코레일 로그인
  ///
  /// 반환: (sessionKey, userName)
  Future<({String sessionKey, String userName})> login(
    String korailId,
    String korailPw,
  ) async {
    try {
      _log('로그인 시작: $korailId');

      // 1. 비밀번호 암호화
      final encrypted = await _crypto.encryptPassword(korailPw);
      _log('암호화 완료 (idx: ${encrypted.idx})');

      // 2. 로그인 유형 판별
      final inputFlg = _detectInputType(korailId);
      _log('로그인 유형: $inputFlg');

      // 3. 로그인 요청
      final response = await _dio.post(
        KorailConstants.loginUrl,
        data: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.loginVersion,
          'txtInputFlg': inputFlg,
          'txtMemberNo': korailId,
          'txtPwd': encrypted.encryptedPw,
          'idx': encrypted.idx,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final data = _parseJson(response.data);
      _log('로그인 응답: strResult=${data['strResult']}');

      // 4. 결과 확인
      final result = data['strResult'] as String? ?? '';
      if (result != 'SUCC') {
        final msgCd = data['h_msg_cd'] as String? ?? '';
        final msg = data['h_msg_txt'] as String? ?? '로그인에 실패했습니다';
        _log('로그인 실패: [$msgCd] $msg');
        throw ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: '[$msgCd] $msg',
        );
      }

      // 5. 세션 저장
      _sessionKey = data['Key'] as String? ?? '';
      _userName = data['strCustNm'] as String? ?? '';

      _log('로그인 성공: $_userName');

      return (sessionKey: _sessionKey!, userName: _userName!);
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      _log('로그인 DioException: ${e.type} ${e.message}');
      throw _handleDioError(e);
    } catch (e) {
      _log('로그인 예외: $e');
      throw NetworkError('로그인 중 오류: $e');
    }
  }

  // ──────────────────────────────────────────
  // 열차 조회
  // ──────────────────────────────────────────

  /// 열차 목록 조회 (하루 전체)
  ///
  /// 코레일 API는 한 번에 10개씩만 반환하므로,
  /// 시간을 증가시키며 반복 호출하여 전체 열차를 가져옵니다.
  Future<List<Train>> searchTrains(
    String dep,
    String arr,
    String date,
    String time,
  ) async {
    _requireSession();

    _trainCache.clear();
    final allTrains = <Train>[];
    final seenTrainKeys = <String>{}; // 중복 방지
    var currentTime = time;

    try {
      // 최대 15번 반복 (korail2 방식)
      for (var i = 0; i < 15; i++) {
        final trains = await _searchTrainsSingle(dep, arr, date, currentTime);

        if (trains.isEmpty) {
          break;
        }

        // 중복 제거하며 추가
        for (final train in trains) {
          final key = '${train.trainNo}_${train.depTime}';
          if (!seenTrainKeys.contains(key)) {
            seenTrainKeys.add(key);
            allTrains.add(train);
          }
        }

        // 마지막 열차의 출발 시간 확인
        final lastTrain = trains.last;
        final lastDepTime = lastTrain.depTime.replaceAll(':', '');

        // 23:59면 종료
        if (lastDepTime.startsWith('23') &&
            int.parse(lastDepTime.substring(2, 4)) >= 59) {
          break;
        }

        // 출발 시간 + 1분으로 다음 검색
        currentTime = _addOneMinute(lastDepTime);
        _log('다음 검색 시간: $currentTime (반복 ${i + 1}/15)');
      }

      _log('전체 열차 조회 완료: ${allTrains.length}개');
      return allTrains;
    } on ApiError {
      // 결과 없음 에러는 현재까지 수집한 열차 반환
      if (allTrains.isNotEmpty) {
        _log('전체 열차 조회 완료 (중단): ${allTrains.length}개');
        return allTrains;
      }
      rethrow;
    }
  }

  /// 단일 열차 조회 (10개)
  Future<List<Train>> _searchTrainsSingle(
    String dep,
    String arr,
    String date,
    String time,
  ) async {
    try {
      final response = await _dio.get(
        KorailConstants.scheduleUrl,
        queryParameters: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.version,
          'Key': _sessionKey,
          'radJobId': '1', // 직통
          'selGoTrain': KorailConstants.trainTypeKtx,
          'txtTrnGpCd': KorailConstants.trainTypeKtx,
          'txtGoStart': dep,
          'txtGoEnd': arr,
          'txtGoAbrdDt': date,
          'txtGoHour': time,
          'txtPsgFlg_1': '1', // 어른 1명
          'txtPsgFlg_2': '0', // 어린이
          'txtPsgFlg_3': '0', // 경로
          'txtPsgFlg_4': '0', // 중증장애인
          'txtPsgFlg_5': '0', // 경증장애인
          'txtSeatAttCd_2': '000',
          'txtSeatAttCd_3': '000',
          'txtSeatAttCd_4': '015',
        },
      );

      final data = _parseJson(response.data);

      // 결과 확인
      final result = data['strResult'] as String? ?? '';
      if (result != 'SUCC') {
        final msgCd = data['h_msg_cd'] as String? ?? '';
        // 결과 없음은 빈 리스트 반환
        if (KorailConstants.errNoResult.contains(msgCd)) {
          return [];
        }
        _handleKorailError(msgCd, data);
      }

      // 열차 목록 파싱
      final trnInfos = data['trn_infos'] as Map<String, dynamic>? ?? {};
      final trnInfoList = trnInfos['trn_info'];

      List<Map<String, dynamic>> trainMaps;
      if (trnInfoList is List) {
        trainMaps = trnInfoList.cast<Map<String, dynamic>>();
      } else if (trnInfoList is Map) {
        trainMaps = [trnInfoList as Map<String, dynamic>];
      } else {
        return [];
      }

      // KorailTrain으로 파싱 → 캐시 저장 → Train으로 변환
      final trains = <Train>[];

      for (final map in trainMaps) {
        final kt = KorailTrain.fromJson(map);
        _trainCache[kt.cacheKey] = kt;
        trains.add(kt.toTrain());
        _log('  열차 ${kt.trainNo} ${kt.depTimeFormatted}→${kt.arrTimeFormatted} '
            '일반=${kt.generalSeatCode}(${kt.hasGeneralSeats}) '
            '특실=${kt.specialSeatCode}(${kt.hasSpecialSeats})');
      }

      return trains;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 시간에 1분 추가 (HHmmss 형식)
  String _addOneMinute(String time) {
    // time: "HHmmss" 또는 "HHmm" 형식
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

  /// 예약 시도
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
      // 캐시에서 KorailTrain 검색
      final kt = _findCachedTrain(trainNo, time);
      if (kt == null) {
        throw const ApiError(
          error: 'NO_TRAINS',
          code: 'SEARCH_002',
          detail: '열차 정보를 찾을 수 없습니다. 다시 조회해 주세요.',
        );
      }

      // 좌석 클래스: '1'(일반), '2'(특실)
      final psrmClCd = seatType == 'special' ? '2' : '1';

      _log('예약 요청 파라미터: trainNo=${kt.trainNo}, depDate=${kt.depDate}, '
          'depTime=${kt.depTime}, runDate=${kt.runDate}, '
          'depCode=${kt.depStationCode}, arrCode=${kt.arrStationCode}, '
          'trainType=${kt.trainType}, trainGroup=${kt.trainGroup}');

      final response = await _dio.get(
        KorailConstants.reservationUrl,
        queryParameters: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.version,
          'Key': _sessionKey,
          'txtGdNo': '',
          'txtJobId': '1101', // 좌석 예약
          'txtTotPsgCnt': '1',
          'txtSeatAttCd1': '000',
          'txtSeatAttCd2': '000',
          'txtSeatAttCd3': '000',
          'txtSeatAttCd4': '015',
          'txtSeatAttCd5': '000',
          'hidFreeFlg': 'N',
          'txtStndFlg': 'N',
          'txtMenuId': '11',
          'txtSrcarCnt': '0',
          'txtJrnyCnt': '1',
          // 승객 정보 (언더스코어 없이)
          'txtPsgTpCd1': '1', // 어른
          'txtDiscKndCd1': '000',
          'txtCompaCnt1': '1',
          'txtCardCode_1': '',
          'txtCardNo_1': '',
          'txtCardPw_1': '',
          // 구간 1 정보 (언더스코어 없이!)
          'txtJrnySqno1': '001',
          'txtJrnyTpCd1': '11',
          'txtDptDt1': kt.depDate,
          'txtDptRsStnCd1': kt.depStationCode,
          'txtDptTm1': kt.depTime,
          'txtArvRsStnCd1': kt.arrStationCode,
          'txtTrnNo1': kt.trainNo,
          'txtRunDt1': kt.runDate,
          'txtTrnClsfCd1': kt.trainType,
          'txtPsrmClCd1': psrmClCd,
          'txtTrnGpCd1': kt.trainGroup,
          'txtChgFlg1': '',
          // 구간 2 (빈 값)
          'txtJrnySqno2': '',
          'txtJrnyTpCd2': '',
          'txtDptDt2': '',
          'txtDptRsStnCd2': '',
          'txtDptTm2': '',
          'txtArvRsStnCd2': '',
          'txtTrnNo2': '',
          'txtRunDt2': '',
          'txtTrnClsfCd2': '',
          'txtPsrmClCd2': '',
          'txtChgFlg2': '',
        },
      );

      final data = _parseJson(response.data);
      _log('예약 응답: strResult=${data['strResult']}, '
          'h_msg_cd=${data['h_msg_cd']}, keys=${data.keys.toList()}');

      final result = data['strResult'] as String? ?? '';
      if (result != 'SUCC') {
        final msgCd = data['h_msg_cd'] as String? ?? '';
        final msg = data['h_msg_txt'] as String? ?? '예약에 실패했습니다';
        _log('예약 실패: [$msgCd] $msg');

        if (msgCd == KorailConstants.errSoldOut) {
          throw ApiError(
            error: 'SOLD_OUT',
            code: 'RESERVE_001',
            detail: msg,
          );
        }

        throw ApiError(
          error: 'RESERVATION_FAILED',
          code: 'RESERVE_002',
          detail: '[$msgCd] $msg',
        );
      }

      // 예약 성공 - 예약번호 추출
      final pnrNo = data['h_pnr_no'] as String? ?? '';
      final resultMsg = data['h_msg_txt'] as String? ?? '예약이 완료되었습니다';
      _log('예약 성공: pnrNo=$pnrNo, 전체 키=${data.keys.toList()}');

      // 취소용 메타데이터 캐시 (fetchReservations 전에도 취소 가능하도록)
      _reservationMeta[pnrNo] = {
        'jrnySqno': data['h_jrny_sqno'] as String? ?? '001',
        'jrnyCnt': data['h_jrny_cnt'] as String? ?? '01',
        'rsvChgNo': data['h_rsv_chg_no'] as String? ?? '00000',
      };

      return Reservation(
        reservationId: pnrNo,
        status: 'success',
        train: kt.toTrain(),
        message: resultMsg,
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

  /// 내 예약 목록 조회
  Future<List<Reservation>> fetchReservations() async {
    _requireSession();

    try {
      final response = await _dio.get(
        KorailConstants.reservationListUrl,
        queryParameters: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.version,
          'Key': _sessionKey,
        },
      );

      final data = _parseJson(response.data);
      _log('예약목록 응답: strResult=${data['strResult']}, '
          'h_msg_cd=${data['h_msg_cd']}, keys=${data.keys.toList()}');

      final result = data['strResult'] as String? ?? '';
      if (result != 'SUCC') {
        final msgCd = data['h_msg_cd'] as String? ?? '';
        _log('예약목록 실패: [$msgCd] ${data['h_msg_txt']}');
        // 예약 없음은 빈 리스트 반환
        if (KorailConstants.errNoResult.contains(msgCd)) {
          return [];
        }
        _handleKorailError(msgCd, data);
      }

      // jrny_infos → jrny_info[] → train_infos → train_info[] 파싱
      final jrnyInfos = data['jrny_infos'] as Map<String, dynamic>? ?? {};
      final jrnyInfoList = _ensureList(jrnyInfos['jrny_info']);
      _log('예약목록 파싱: jrnyInfoList.length=${jrnyInfoList.length}');

      final reservations = <Reservation>[];

      for (final jrny in jrnyInfoList) {
        final jrnyMap = jrny as Map<String, dynamic>;
        final pnrNo = jrnyMap['h_pnr_no'] as String? ?? '';
        final jrnySqno = jrnyMap['h_jrny_sqno'] as String? ?? '';
        final jrnyCnt = jrnyMap['h_jrny_cnt'] as String? ?? '';

        final trainInfos =
            jrnyMap['train_infos'] as Map<String, dynamic>? ?? {};
        final trainInfoList = _ensureList(trainInfos['train_info']);

        for (final ti in trainInfoList) {
          final tiMap = ti as Map<String, dynamic>;

          final rsvChgNo = tiMap['h_rsv_chg_no'] as String? ?? '';

          // 취소용 메타데이터 캐시
          _reservationMeta[pnrNo] = {
            'jrnySqno': jrnySqno,
            'jrnyCnt': jrnyCnt,
            'rsvChgNo': rsvChgNo,
          };

          final train = Train(
            trainNo: (tiMap['h_trn_no'] as String? ?? '').trim(),
            trainType: (tiMap['h_trn_clsf_nm'] as String? ?? '').trim(),
            depStation: (tiMap['h_dpt_rs_stn_nm'] as String? ?? '').trim(),
            arrStation: (tiMap['h_arv_rs_stn_nm'] as String? ?? '').trim(),
            depTime: _formatTime(tiMap['h_dpt_tm'] as String? ?? ''),
            arrTime: _formatTime(tiMap['h_arv_tm'] as String? ?? ''),
          );

          reservations.add(Reservation(
            reservationId: pnrNo,
            status: 'success',
            train: train,
            message: '',
            reservedAt: DateTime.now(),
          ));
        }
      }

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

  /// 예약 취소
  Future<Map<String, dynamic>> cancelReservation(String reservationId) async {
    _requireSession();

    try {
      final meta = _reservationMeta[reservationId];
      final jrnySqno = meta?['jrnySqno'] ?? '001';
      final jrnyCnt = meta?['jrnyCnt'] ?? '01';
      final rsvChgNo = meta?['rsvChgNo'] ?? '00000';

      _log('예약취소 요청: pnrNo=$reservationId, jrnySqno=$jrnySqno, '
          'jrnyCnt=$jrnyCnt, rsvChgNo=$rsvChgNo');

      final response = await _dio.get(
        KorailConstants.cancelUrl,
        queryParameters: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.version,
          'Key': _sessionKey,
          'txtPnrNo': reservationId,
          'txtJrnySqno': jrnySqno,
          'txtJrnyCnt': jrnyCnt,
          'hidRsvChgNo': rsvChgNo,
        },
      );

      final data = _parseJson(response.data);

      final result = data['strResult'] as String? ?? '';
      if (result != 'SUCC') {
        final msgCd = data['h_msg_cd'] as String? ?? '';
        final msg = data['h_msg_txt'] as String? ?? '취소에 실패했습니다';
        throw ApiError(
          error: 'CANCEL_FAILED',
          code: 'RESERVE_003',
          detail: '[$msgCd] $msg',
        );
      }

      _reservationMeta.remove(reservationId);

      return {
        'message': data['h_msg_txt'] as String? ?? '예약이 취소되었습니다',
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

  /// 로그아웃 (세션 초기화)
  void logout() {
    _sessionKey = null;
    _userName = null;
    _trainCache.clear();
    _reservationMeta.clear();
    _cookieJar.deleteAll();
    _log('로그아웃 완료');
  }

  // ──────────────────────────────────────────
  // 내부 헬퍼
  // ──────────────────────────────────────────

  /// 응답 데이터를 Map으로 파싱 (String/Map 모두 처리)
  Map<String, dynamic> _parseJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final parsed = json.decode(data);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (e) {
        _log('JSON 파싱 실패: $e / 원본: ${data.length > 200 ? data.substring(0, 200) : data}');
      }
    }
    throw const ApiError(
      error: 'KORAIL_SERVER_ERROR',
      code: 'SYSTEM_002',
      detail: '서버 응답을 처리할 수 없습니다',
    );
  }

  /// 세션 확인
  void _requireSession() {
    if (_sessionKey == null) {
      throw const ApiError(
        error: 'SESSION_EXPIRED',
        code: 'AUTH_003',
        detail: '로그인이 필요합니다',
      );
    }
  }

  /// 로그인 ID 유형 판별
  String _detectInputType(String id) {
    if (id.contains('@')) return '5'; // 이메일
    if (RegExp(r'^\d{10,}$').hasMatch(id)) return '2'; // 회원번호
    return '4'; // 전화번호
  }

  /// 캐시에서 열차 검색
  KorailTrain? _findCachedTrain(String trainNo, String time) {
    final trimmedNo = trainNo.trim();
    for (final entry in _trainCache.entries) {
      if (entry.value.trainNo.trim() == trimmedNo) {
        return entry.value;
      }
    }
    return null;
  }

  /// 코레일 에러 코드 처리
  Never _handleKorailError(String msgCd, Map<String, dynamic> data) {
    final msg = data['h_msg_txt'] as String? ?? '오류가 발생했습니다';

    if (msgCd == KorailConstants.errNeedLogin) {
      _sessionKey = null;
      throw ApiError(
        error: 'SESSION_EXPIRED',
        code: 'AUTH_003',
        detail: msg,
      );
    }

    if (KorailConstants.errNoResult.contains(msgCd)) {
      throw ApiError(
        error: 'NO_TRAINS',
        code: 'SEARCH_002',
        detail: msg,
      );
    }

    if (msgCd == KorailConstants.errSoldOut) {
      throw ApiError(
        error: 'SOLD_OUT',
        code: 'RESERVE_001',
        detail: msg,
      );
    }

    throw ApiError(
      error: 'KORAIL_SERVER_ERROR',
      code: 'SYSTEM_002',
      detail: '[$msgCd] $msg',
    );
  }

  /// DioException → 구조화된 에러
  Exception _handleDioError(DioException e) {
    _log('DioError 상세: type=${e.type}, message=${e.message}, '
        'error=${e.error}, statusCode=${e.response?.statusCode}');
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkError('코레일 서버 연결 시간이 초과되었습니다');
      case DioExceptionType.receiveTimeout:
        return const NetworkError('코레일 서버 응답 대기 시간이 초과되었습니다');
      case DioExceptionType.connectionError:
        return NetworkError('코레일 서버에 연결할 수 없습니다: ${e.error}');
      default:
        return NetworkError(e.message ?? '네트워크 오류가 발생했습니다');
    }
  }

  /// 시간 포맷 (HHmmss → HH:mm)
  String _formatTime(String raw) {
    if (raw.length >= 4) {
      return '${raw.substring(0, 2)}:${raw.substring(2, 4)}';
    }
    return raw;
  }

  /// JSON 값을 List로 정규화 (단일 객체도 리스트로)
  List _ensureList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return [];
  }

  /// 로그 출력 (print + dev.log 모두 사용)
  void _log(String message) {
    // ignore: avoid_print
    print('[KorailApi] $message');
    dev.log(message, name: 'KorailApi');
  }
}
