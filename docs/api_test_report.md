# Korail API 테스트 리포트

**테스트 일시**: 2026-02-05 19:15 KST
**테스트 환경**: Android (SM-G965N, Android 10)
**API 버전**: Dart 직접 구현 (Python 백엔드 제거됨)

---

## 1. 테스트 요약

| API | 상태 | 응답코드 | 비고 |
|-----|------|---------|------|
| 암호화 키 획득 | ✅ PASS | 200 | idx: 83, 08 |
| 로그인 | ✅ PASS | 200 | strResult=SUCC |
| 예약 목록 조회 | ✅ PASS | 200 | 0건 (정상) |
| 열차 조회 | ✅ PASS | 200 | 10개 열차 반환 |
| 예약 | ⏳ 미테스트 | - | 예약 가능 기간 필요 |
| 예약 취소 | ⏳ 미테스트 | - | 예약 생성 후 테스트 |

---

## 2. 상세 테스트 결과

### 2.1 암호화 키 획득 ✅ PASS

```
POST /classes/com.korail.mobile.common.code.do
Request: {code: 'app.login.cphd'}
Response: 200 OK

[KorailCrypto] 암호화 키 획득 성공 (idx: 83, keyLen: 32)
[KorailCrypto] 암호화 키 획득 성공 (idx: 08, keyLen: 32)
```

---

### 2.2 로그인 ✅ PASS

```
POST /classes/com.korail.mobile.login.Login
Response: 200 OK

[KorailApi] 로그인 응답: strResult=SUCC
[KorailApi] 로그인 성공: 김태우
```

**로그인 유형**: 회원번호 (`txtInputFlg=2`)

---

### 2.3 예약 목록 조회 ✅ PASS

```
GET /classes/com.korail.mobile.reservation.ReservationView
Response: 200 OK

[KorailApi] 예약목록 응답: strResult=SUCC, h_msg_cd=P100
[KorailApi] 예약목록 파싱: jrnyInfoList.length=0
```

**참고**: `h_msg_cd=P100`은 예약 없음 (정상)

---

### 2.4 열차 조회 ✅ PASS

```
GET /classes/com.korail.mobile.seatMovie.ScheduleView
Parameters:
  - txtGoStart: 서울
  - txtGoEnd: 영등포
  - txtGoAbrdDt: 20260206
  - txtGoHour: 090000
Response: 200 OK

[KorailApi] 열차조회 응답: strResult=SUCC, h_msg_cd=IRG000000
[KorailApi] 열차조회 파싱: trnInfoList type=List<dynamic>
```

**조회된 열차 목록**:

| 열차번호 | 출발 | 도착 | 일반실 | 특실 |
|---------|------|------|--------|------|
| 1111 | 09:08 | 09:17 | ✅ | ❌ |
| 1201 | 09:14 | 09:23 | ✅ | ❌ |
| 1573 | 09:38 | 09:46 | ✅ | ❌ |
| 1403 | 09:47 | 09:54 | ✅ | ❌ |
| 1503 | 09:47 | 09:54 | ✅ | ❌ |
| 1441 | 09:56 | 10:04 | ✅ | ❌ |
| 123 | 10:12 | 10:21 | ✅ | ✅ |
| 1009 | 10:23 | 10:32 | ✅ | ❌ |
| 1277 | 10:33 | 10:41 | ✅ | ❌ |
| 1011 | 10:48 | 10:57 | ✅ | ❌ |

---

## 3. 아키텍처 변경 사항

### 변경 전
```
App → ApiClient(Dio) → Python FastAPI → korail2(Python) → 코레일 서버
```

### 변경 후
```
App → KorailApi(Dart/Dio) → 코레일 서버 (직접 통신)
```

---

## 4. 신규 생성 파일

| 파일 | 설명 |
|------|------|
| `lib/data/services/korail_constants.dart` | API URL, 상수 정의 |
| `lib/data/services/korail_crypto.dart` | AES-256-CBC 암호화 |
| `lib/data/services/korail_api.dart` | 메인 API 클라이언트 |
| `lib/data/models/korail_train.dart` | 내부 열차 모델 |

---

## 5. 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `pubspec.yaml` | encrypt, dio_cookie_manager, cookie_jar 추가 |
| `lib/data/repositories/train_repository.dart` | KorailApi 사용으로 변경 |

---

## 6. 해결된 이슈

| 이슈 | 원인 | 해결 |
|------|------|------|
| 암호화 키 파싱 오류 | 중첩 응답 구조 | `data['app.login.cphd']['key']` 탐색 |
| 승객수 오류 (WRP011002) | 파라미터명 언더스코어 | `txtPsgTpCd1` (언더스코어 제거) |
| 예약 취소 입력값 오류 | jrnyCnt 한 자리 | `'01'` (두 자리) |

---

## 7. 결론

Python 백엔드 제거 후 Dart 직접 구현이 **정상 동작**함을 확인했습니다.

- ✅ 로그인 플로우 (암호화 포함) 정상
- ✅ 열차 조회 정상 (좌석 가용성 파싱 포함)
- ✅ 예약 목록 조회 정상
- ⏳ 예약/취소는 예약 가능 기간에 추가 테스트 필요

---

*문서 작성: Claude Code*
*최종 업데이트: 2026-02-05 19:15 KST*
