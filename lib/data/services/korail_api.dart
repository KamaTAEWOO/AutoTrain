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
import 'korail_dynapath.dart';
import 'train_api_service.dart';

/// 코레일 서버와 직접 통신하는 API 클라이언트
///
/// Python 백엔드 없이 코레일 모바일 API를 직접 호출한다.
class KorailApi implements TrainApiService {
  static KorailApi? _instance;

  late final Dio _dio;
  late final CookieJar _cookieJar;
  late final KorailCrypto _crypto;
  late final KorailDynaPath _dynapath;

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
        // 실제 KorailTalk 앱이 보내는 헤더와 동일하게 맞춰야 MACRO 탐지를 회피.
        // User-Agent만 설정하고 나머지를 Dio 기본값에 맡기면 서버가 매크로로 판별.
        headers: {
          'User-Agent': KorailConstants.userAgent,
          'Host': KorailConstants.host,
          'Connection': 'Keep-Alive',
          'Accept-Encoding': 'gzip',
        },
        contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
        // 코레일 서버는 JSON이지만 content-type이 부정확할 수 있으므로 plain으로 수신
        responseType: ResponseType.plain,
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));

    _dynapath = KorailDynaPath();

    // Dynapath 토큰 자동 주입 인터셉터 (보호 엔드포인트만 대상)
    //
    // dhfhfk/korail2 원본 동작:
    // - 로그인: Sid = Dynapath 생성값 (세션 키 없음), x-dynapath-m-token 헤더
    // - 그 외: Sid = 세션 키 (이미 각 메서드에서 넣음), x-dynapath-m-token 헤더
    //
    // 따라서 Sid는 요청에 이미 값이 있으면 덮어쓰지 않는다.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final auth = _dynapath.buildAuth(options.path);
          if (auth.headers.isNotEmpty) {
            options.headers.addAll(auth.headers);
          }
          if (auth.sid != null) {
            if (options.method == 'GET') {
              final existing = options.queryParameters['Sid'];
              if (existing == null || (existing is String && existing.isEmpty)) {
                options.queryParameters = <String, dynamic>{
                  ...options.queryParameters,
                  'Sid': auth.sid!,
                };
              }
            } else if (options.method == 'POST') {
              final data = options.data;
              if (data is Map && !data.containsKey('Sid')) {
                // Dio transformer는 Map<String, dynamic>만 인코딩 가능
                final merged = <String, dynamic>{};
                data.forEach((k, v) => merged[k.toString()] = v);
                merged['Sid'] = auth.sid!;
                options.data = merged;
              }
            }
          }
          handler.next(options);
        },
      ),
    );

    // 로깅 인터셉터 (진단용: 실제 전송되는 헤더 확인)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log('→ ${options.method} ${options.uri}');
          _log('  headers: ${options.headers}');
          if (options.method == 'POST' && options.data != null) {
            final data = options.data;
            if (data is Map) {
              final redacted = Map.of(data);
              if (redacted.containsKey('txtPwd')) {
                redacted['txtPwd'] = '[REDACTED]';
              }
              if (redacted.containsKey('x-dynapath-m-token')) {
                redacted['x-dynapath-m-token'] = '[REDACTED]';
              }
              _log('  data: $redacted');
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _log('← ${response.statusCode} ${response.requestOptions.path}');
          _log('  resp headers: ${response.headers.map}');
          handler.next(response);
        },
        onError: (error, handler) {
          _log('✗ ${error.type} ${error.response?.statusCode} '
              '${error.requestOptions.uri}: ${error.message}');
          _log('  resp headers: ${error.response?.headers.map}');
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
  @override
  bool get hasSession => _sessionKey != null;

  /// 로그인한 사용자 이름
  @override
  String? get userName => _userName;

  // ──────────────────────────────────────────
  // 로그인
  // ──────────────────────────────────────────

  /// 코레일 로그인
  ///
  /// 반환: (sessionKey, userName)
  @override
  Future<({String sessionKey, String userName})> login(
    String korailId,
    String korailPw,
  ) async {
    try {
      _log('로그인 시작: ${korailId.replaceRange(3, korailId.length - 2, '***')}');

      // 1. 비밀번호 암호화
      final encrypted = await _crypto.encryptPassword(korailPw);
      _log('암호화 완료 (idx: ${encrypted.idx})');

      // 2. 로그인 유형 판별
      final inputFlg = _detectInputType(korailId);
      // 전화번호인 경우 하이픈 등 특수문자 제거
      final cleanId = inputFlg == '4'
          ? korailId.replaceAll(RegExp(r'[^0-9]'), '')
          : korailId;
      _log('로그인 유형: $inputFlg');

      // 3. 로그인 요청 (srtgo 기준: Device, Version, Key, txtMemberNo, txtPwd,
      // txtInputFlg, idx 전체 포함 — 순서도 srtgo와 동일하게 맞춤)
      final response = await _dio.post(
        KorailConstants.loginUrl,
        data: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.loginVersion,
          'Key': KorailConstants.staticKey,
          'txtMemberNo': cleanId,
          'txtPwd': encrypted.encryptedPw,
          'txtInputFlg': inputFlg,
          'idx': encrypted.idx,
        },
      );

      final data = _parseJson(response.data);
      _log('로그인 응답: strResult=${data['strResult']}, keys=${data.keys.toList()}');

      // 4. 결과 확인
      final result = data['strResult'] as String? ?? '';
      final msgCd = data['h_msg_cd'] as String? ?? '';
      final msgTxt = data['h_msg_txt'] as String? ?? '';

      if (result != 'SUCC') {
        _log('로그인 실패: [$msgCd] $msgTxt');
        _log('로그인 실패 전체응답: $data');
        throw ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: msgTxt.isNotEmpty ? '[$msgCd] $msgTxt' : '로그인에 실패했습니다',
        );
      }

      // SUCC이지만 서버 장애 메시지인 경우 (S003 등)
      if (msgCd == 'S003' || msgTxt.contains('서비스에 문제가 발생')) {
        _log('서버 장애: [$msgCd] $msgTxt');
        throw ApiError(
          error: 'SERVER_ERROR',
          code: 'SYSTEM_001',
          detail: msgTxt.isNotEmpty ? msgTxt : '서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
        );
      }

      // 5. 세션 저장 (dhfhfk/korail2: strMbCrdNo로 실제 로그인 여부 확인)
      final mbCrdNo = data['strMbCrdNo'] as String? ?? '';
      _sessionKey = data['Key'] as String? ?? '';
      _userName = data['strCustNm'] as String? ?? '';

      if (mbCrdNo.isEmpty && _sessionKey!.isEmpty) {
        _log('로그인 실패: 세션 키 없음. 응답 전체=$data');
        throw ApiError(
          error: 'LOGIN_FAILED',
          code: 'AUTH_001',
          detail: msgTxt.isNotEmpty ? msgTxt : '로그인에 실패했습니다',
        );
      }

      // Key가 없지만 membership이 있으면 membership을 세션 식별자로 사용
      if (_sessionKey!.isEmpty && mbCrdNo.isNotEmpty) {
        _sessionKey = mbCrdNo;
        _log('세션 키 없음 → strMbCrdNo($mbCrdNo)를 세션으로 사용');
      }

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
          'Sid': _sessionKey ?? '',
          'txtMenuId': KorailConstants.menuId,
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
          'ebizCrossCheck': 'N',
          'srtCheckYn': 'N',
          'rtYn': 'N',
          'adjStnScdlOfrFlg': 'N',
          'mbCrdNo': '',
        },
      );

      final data = _parseJson(response.data);

      // 결과 확인
      final result = data['strResult'] as String? ?? '';
      final msgCd = data['h_msg_cd'] as String? ?? '';
      final msgTxt = data['h_msg_txt'] as String? ?? '';
      _log('열차조회 응답: strResult=$result, h_msg_cd=$msgCd, h_msg_txt=$msgTxt');

      if (result != 'SUCC') {
        _log('열차조회 실패: [$msgCd] $msgTxt');
        // 결과 없음은 빈 리스트 반환
        if (KorailConstants.errNoResult.contains(msgCd)) {
          return [];
        }
        _handleKorailError(msgCd, data);
      }

      // 열차 목록 파싱
      final trnInfos = data['trn_infos'] as Map<String, dynamic>? ?? {};
      final trnInfoList = trnInfos['trn_info'];
      _log('열차 파싱: trn_infos keys=${trnInfos.keys.toList()}, '
          'trn_info type=${trnInfoList.runtimeType}');

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
          'Key': KorailConstants.staticKey,
          'Sid': _sessionKey ?? '',
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
  @override
  Future<List<Reservation>> fetchReservations() async {
    _requireSession();

    try {
      final response = await _dio.get(
        KorailConstants.reservationListUrl,
        queryParameters: {
          'Device': KorailConstants.device,
          'Version': KorailConstants.version,
          'Key': KorailConstants.staticKey,
          'Sid': _sessionKey ?? '',
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
  @override
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
          'Key': KorailConstants.staticKey,
          'Sid': _sessionKey ?? '',
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
  @override
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
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    // 01X로 시작하는 10~11자리 → 전화번호
    if (RegExp(r'^01\d{8,9}$').hasMatch(digits)) return '4';
    // 그 외 숫자 → 회원번호
    if (RegExp(r'^\d{10,}$').hasMatch(digits)) return '2';
    return '4'; // 기본: 전화번호
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
