# KTX 자동 조회/예약 테스트 앱 - API 스펙 문서

---

## 1. 개요

### 1.1 기본 정보

| 항목 | 값 |
|------|-----|
| Base URL | `http://localhost:8000` |
| API Prefix | `/api` |
| Content-Type | `application/json` |
| 문자 인코딩 | UTF-8 |
| 인증 방식 | Bearer Token (로그인 후 발급) |
| 타임아웃 | 연결 10초 / 응답 30초 |

### 1.2 공통 헤더

**요청 헤더**

| 헤더 | 값 | 필수 | 설명 |
|------|-----|------|------|
| Content-Type | application/json | O | 요청 본문 형식 |
| Accept | application/json | O | 응답 형식 |
| Authorization | Bearer {session_token} | 조건부 | 로그인 이후 API에 필수 |

### 1.3 공통 에러 응답 포맷

모든 에러 응답은 아래 형식을 따른다.

```json
{
  "error": "ERROR_TYPE",
  "code": "CATEGORY_NNN",
  "detail": "사람이 읽을 수 있는 에러 메시지"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| error | string | 에러 타입 (대문자 SNAKE_CASE) |
| code | string | 에러 코드 (카테고리_숫자 3자리) |
| detail | string | 사용자에게 표시 가능한 에러 설명 (한국어) |

### 1.4 에러 코드 체계

| 범주 | 코드 범위 | 설명 | 예시 |
|------|-----------|------|------|
| **AUTH** | AUTH_001 ~ AUTH_099 | 인증/로그인 관련 | AUTH_001: 로그인 실패 |
| **SEARCH** | SEARCH_001 ~ SEARCH_099 | 열차 검색 관련 | SEARCH_001: 잘못된 파라미터 |
| **RESERVE** | RESERVE_001 ~ RESERVE_099 | 예약 관련 | RESERVE_001: 매진 |
| **SYSTEM** | SYSTEM_001 ~ SYSTEM_099 | 시스템/서버 관련 | SYSTEM_001: 내부 서버 오류 |

---

## 2. API 엔드포인트 상세

---

### 2.1 POST /api/auth/login

코레일 계정으로 로그인하여 세션 토큰을 발급받는다.

#### 요청

**URL**: `POST /api/auth/login`

**Headers**:

| 헤더 | 값 |
|------|-----|
| Content-Type | application/json |

**Request Body**:

```json
{
  "korail_id": "string",
  "korail_pw": "string"
}
```

| 필드 | 타입 | 필수 | 설명 | 예시 |
|------|------|------|------|------|
| korail_id | string | O | 코레일 멤버십 번호 또는 이메일 | "1234567890" |
| korail_pw | string | O | 코레일 비밀번호 | "password123" |

#### 응답

**200 OK - 로그인 성공**

```json
{
  "session_token": "abc123def456",
  "expires_at": "2026-02-02T15:30:00+09:00",
  "message": "로그인 성공"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| session_token | string | 세션 토큰 (이후 API 호출 시 Authorization 헤더에 사용) |
| expires_at | string (ISO 8601) | 세션 만료 시각 |
| message | string | 결과 메시지 |

**401 Unauthorized - 로그인 실패**

```json
{
  "error": "LOGIN_FAILED",
  "code": "AUTH_001",
  "detail": "아이디 또는 비밀번호가 올바르지 않습니다"
}
```

**403 Forbidden - 계정 차단**

```json
{
  "error": "ACCOUNT_BLOCKED",
  "code": "AUTH_002",
  "detail": "계정이 제한되었습니다"
}
```

#### cURL 예시

```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "korail_id": "1234567890",
    "korail_pw": "password123"
  }'
```

#### 시퀀스 다이어그램

```
Flutter App              FastAPI                  korail2              코레일 서버
    │                       │                       │                     │
    │  POST /api/auth/login │                       │                     │
    ├──────────────────────►│                       │                     │
    │  {korail_id, korail_pw}                       │                     │
    │                       │  Korail(id, pw)       │                     │
    │                       ├──────────────────────►│  HTTP 로그인 요청    │
    │                       │                       ├────────────────────►│
    │                       │                       │◄────────────────────┤
    │                       │◄──────────────────────┤  로그인 결과         │
    │  200 {session_token}  │                       │                     │
    │◄──────────────────────┤                       │                     │
    │                       │                       │                     │
```

---

### 2.2 GET /api/trains/search

출발역/도착역/날짜/시간 조건으로 KTX 열차 목록을 조회한다.

#### 요청

**URL**: `GET /api/trains/search?dep={dep}&arr={arr}&date={date}&time={time}`

**Headers**:

| 헤더 | 값 |
|------|-----|
| Authorization | Bearer {session_token} |

**Query Parameters**:

| 파라미터 | 타입 | 필수 | 설명 | 형식 | 예시 |
|---------|------|------|------|------|------|
| dep | string | O | 출발역 이름 | 한글 역명 | 서울 |
| arr | string | O | 도착역 이름 | 한글 역명 | 부산 |
| date | string | O | 출발 날짜 | YYYYMMDD | 20260205 |
| time | string | O | 출발 시간 (이후) | HHmmss | 090000 |

#### 응답

**200 OK - 조회 성공**

```json
{
  "trains": [
    {
      "train_no": "KTX-101",
      "train_type": "KTX",
      "dep_station": "서울",
      "arr_station": "부산",
      "dep_time": "09:00",
      "arr_time": "11:30",
      "general_seats": true,
      "special_seats": false
    },
    {
      "train_no": "KTX-103",
      "train_type": "KTX",
      "dep_station": "서울",
      "arr_station": "부산",
      "dep_time": "10:00",
      "arr_time": "12:30",
      "general_seats": false,
      "special_seats": false
    }
  ],
  "searched_at": "2026-02-02T14:32:05+09:00"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| trains | array | 열차 정보 배열 |
| trains[].train_no | string | 열차 번호 |
| trains[].train_type | string | 열차 종류 (KTX, KTX-산천 등) |
| trains[].dep_station | string | 출발역 |
| trains[].arr_station | string | 도착역 |
| trains[].dep_time | string | 출발 시간 (HH:mm) |
| trains[].arr_time | string | 도착 시간 (HH:mm) |
| trains[].general_seats | boolean | 일반실 좌석 여부 (true: 있음) |
| trains[].special_seats | boolean | 특실 좌석 여부 (true: 있음) |
| searched_at | string (ISO 8601) | 조회 시각 |

**400 Bad Request - 잘못된 파라미터**

```json
{
  "error": "INVALID_PARAMS",
  "code": "SEARCH_001",
  "detail": "출발역은 필수 입력값입니다"
}
```

파라미터별 상세 에러:

| 조건 | detail 메시지 |
|------|-------------|
| dep 누락 | "출발역은 필수 입력값입니다" |
| arr 누락 | "도착역은 필수 입력값입니다" |
| date 형식 오류 | "날짜 형식이 올바르지 않습니다 (YYYYMMDD)" |
| time 형식 오류 | "시간 형식이 올바르지 않습니다 (HHmmss)" |
| dep == arr | "출발역과 도착역이 같을 수 없습니다" |
| 존재하지 않는 역명 | "유효하지 않은 역명입니다: {역명}" |
| 과거 날짜 | "과거 날짜는 조회할 수 없습니다" |

**401 Unauthorized - 세션 만료**

```json
{
  "error": "SESSION_EXPIRED",
  "code": "AUTH_003",
  "detail": "세션이 만료되었습니다. 다시 로그인해주세요"
}
```

**404 Not Found - 열차 없음**

```json
{
  "error": "NO_TRAINS",
  "code": "SEARCH_002",
  "detail": "해당 조건의 열차가 없습니다"
}
```

**503 Service Unavailable - 코레일 서버 오류**

```json
{
  "error": "KORAIL_SERVER_ERROR",
  "code": "SEARCH_003",
  "detail": "코레일 서버 연결 실패"
}
```

#### cURL 예시

```bash
curl -X GET "http://localhost:8000/api/trains/search?dep=서울&arr=부산&date=20260205&time=090000" \
  -H "Authorization: Bearer abc123def456"
```

#### 시퀀스 다이어그램

```
Flutter App              FastAPI                  korail2              코레일 서버
    │                       │                       │                     │
    │  GET /api/trains/     │                       │                     │
    │  search?dep=서울&...  │                       │                     │
    ├──────────────────────►│                       │                     │
    │  Authorization: Bearer│                       │                     │
    │                       │  세션 유효성 검사       │                     │
    │                       │  search_train(...)    │                     │
    │                       ├──────────────────────►│  HTTP 조회 요청      │
    │                       │                       ├────────────────────►│
    │                       │                       │◄────────────────────┤
    │                       │◄──────────────────────┤  열차 목록           │
    │  200 {trains: [...]}  │                       │                     │
    │◄──────────────────────┤                       │                     │
    │                       │                       │                     │
```

---

### 2.3 POST /api/reservation

선택한 열차에 대해 예약을 시도한다. 결제는 포함하지 않으며, 예약 생성까지만 수행한다.

#### 요청

**URL**: `POST /api/reservation`

**Headers**:

| 헤더 | 값 |
|------|-----|
| Content-Type | application/json |
| Authorization | Bearer {session_token} |

**Request Body**:

```json
{
  "train_no": "KTX-101",
  "seat_type": "general"
}
```

| 필드 | 타입 | 필수 | 설명 | 유효값 |
|------|------|------|------|--------|
| train_no | string | O | 예약할 열차 번호 | 조회 결과의 train_no |
| seat_type | string | O | 좌석 유형 | "general" (일반실), "special" (특실) |

#### 응답

**200 OK - 예약 성공**

```json
{
  "reservation_id": "R20260202001",
  "status": "success",
  "train": {
    "train_no": "KTX-101",
    "train_type": "KTX",
    "dep_station": "서울",
    "arr_station": "부산",
    "dep_time": "09:00",
    "arr_time": "11:30",
    "general_seats": true,
    "special_seats": false
  },
  "message": "예약 성공. 10분 내 결제 필요",
  "reserved_at": "2026-02-02T14:32:05+09:00"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| reservation_id | string | 예약 번호 |
| status | string | 예약 상태 ("success") |
| train | object | 예약된 열차 정보 (TrainInfo 구조) |
| message | string | 결과 메시지 (결제 안내 포함) |
| reserved_at | string (ISO 8601) | 예약 시각 |

**401 Unauthorized - 세션 만료**

```json
{
  "error": "SESSION_EXPIRED",
  "code": "RESERVE_002",
  "detail": "세션이 만료되었습니다"
}
```

**409 Conflict - 매진**

```json
{
  "error": "SOLD_OUT",
  "code": "RESERVE_001",
  "detail": "매진되었습니다"
}
```

**503 Service Unavailable - 코레일 서버 오류**

```json
{
  "error": "KORAIL_SERVER_ERROR",
  "code": "SYSTEM_002",
  "detail": "코레일 서버와 통신할 수 없습니다"
}
```

#### cURL 예시

```bash
curl -X POST http://localhost:8000/api/reservation \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer abc123def456" \
  -d '{
    "train_no": "KTX-101",
    "seat_type": "general"
  }'
```

#### 시퀀스 다이어그램

```
Flutter App              FastAPI                  korail2              코레일 서버
    │                       │                       │                     │
    │  POST /api/reservation│                       │                     │
    ├──────────────────────►│                       │                     │
    │  {train_no, seat_type}│                       │                     │
    │  Authorization: Bearer│                       │                     │
    │                       │  세션 유효성 검사       │                     │
    │                       │  reserve(train)       │                     │
    │                       ├──────────────────────►│  HTTP 예약 요청      │
    │                       │                       ├────────────────────►│
    │                       │                       │◄────────────────────┤
    │                       │◄──────────────────────┤  예약 결과           │
    │  200 {reservation_id} │                       │                     │
    │◄──────────────────────┤                       │                     │
    │                       │                       │                     │
```

#### 자동 예약 흐름 (자동 조회 모드에서의 예약 시도)

```
Flutter App (MonitorProvider)                FastAPI
    │                                           │
    │  [Timer.periodic: 10초 간격]               │
    │                                           │
    │  GET /api/trains/search                   │
    ├──────────────────────────────────────────►│
    │◄──────────────────────────────────────────┤
    │  trains[0].general_seats == false          │
    │  → 상태: searching (계속 조회)             │
    │                                           │
    │  ... (반복) ...                            │
    │                                           │
    │  GET /api/trains/search                   │
    ├──────────────────────────────────────────►│
    │◄──────────────────────────────────────────┤
    │  trains[0].general_seats == true           │
    │  → 상태: found → reserving                │
    │                                           │
    │  POST /api/reservation                    │
    ├──────────────────────────────────────────►│
    │◄──────────────────────────────────────────┤
    │  → 성공: 상태 success, 결과 화면 전환      │
    │  → 실패(매진): 상태 failure → searching    │
    │    (자동으로 조회 모드 복귀)                │
    │                                           │
```

---

### 2.4 GET /api/reservation/{reservation_id}

예약 번호로 예약 상세 정보를 조회한다.

#### 요청

**URL**: `GET /api/reservation/{reservation_id}`

**Headers**:

| 헤더 | 값 |
|------|-----|
| Authorization | Bearer {session_token} |

**Path Parameters**:

| 파라미터 | 타입 | 필수 | 설명 | 예시 |
|---------|------|------|------|------|
| reservation_id | string | O | 예약 번호 | R20260202001 |

#### 응답

**200 OK - 조회 성공**

```json
{
  "reservation_id": "R20260202001",
  "status": "success",
  "train": {
    "train_no": "KTX-101",
    "train_type": "KTX",
    "dep_station": "서울",
    "arr_station": "부산",
    "dep_time": "09:00",
    "arr_time": "11:30",
    "general_seats": true,
    "special_seats": false
  },
  "reserved_at": "2026-02-02T14:32:05+09:00",
  "payment_deadline": "2026-02-02T14:42:05+09:00"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| reservation_id | string | 예약 번호 |
| status | string | 예약 상태 ("success") |
| train | object | 예약된 열차 정보 |
| reserved_at | string (ISO 8601) | 예약 시각 |
| payment_deadline | string (ISO 8601) | 결제 기한 (예약 후 10분) |

**401 Unauthorized - 세션 만료**

```json
{
  "error": "SESSION_EXPIRED",
  "code": "RESERVE_002",
  "detail": "세션이 만료되었습니다"
}
```

**404 Not Found - 예약 없음**

```json
{
  "error": "NOT_FOUND",
  "code": "RESERVE_003",
  "detail": "예약을 찾을 수 없습니다"
}
```

#### cURL 예시

```bash
curl -X GET http://localhost:8000/api/reservation/R20260202001 \
  -H "Authorization: Bearer abc123def456"
```

---

## 3. 전체 에러 코드 목록

### 3.1 AUTH (인증)

| 코드 | HTTP Status | error | detail |
|------|-------------|-------|--------|
| AUTH_001 | 401 | LOGIN_FAILED | 아이디 또는 비밀번호가 올바르지 않습니다 |
| AUTH_002 | 403 | ACCOUNT_BLOCKED | 계정이 제한되었습니다 |
| AUTH_003 | 401 | SESSION_EXPIRED | 세션이 만료되었습니다. 다시 로그인해주세요 |

### 3.2 SEARCH (검색)

| 코드 | HTTP Status | error | detail |
|------|-------------|-------|--------|
| SEARCH_001 | 400 | INVALID_PARAMS | (파라미터별 상세 메시지) |
| SEARCH_002 | 404 | NO_TRAINS | 해당 조건의 열차가 없습니다 |
| SEARCH_003 | 503 | KORAIL_SERVER_ERROR | 코레일 서버 연결 실패 |

### 3.3 RESERVE (예약)

| 코드 | HTTP Status | error | detail |
|------|-------------|-------|--------|
| RESERVE_001 | 409 | SOLD_OUT | 매진되었습니다 |
| RESERVE_002 | 401 | SESSION_EXPIRED | 세션이 만료되었습니다 |
| RESERVE_003 | 404 | NOT_FOUND | 예약을 찾을 수 없습니다 |

### 3.4 SYSTEM (시스템)

| 코드 | HTTP Status | error | detail |
|------|-------------|-------|--------|
| SYSTEM_001 | 500 | INTERNAL_ERROR | 서버 내부 오류가 발생했습니다 |
| SYSTEM_002 | 503 | KORAIL_SERVER_ERROR | 코레일 서버와 통신할 수 없습니다 |
| SYSTEM_003 | 504 | REQUEST_TIMEOUT | 요청 시간이 초과되었습니다 |

---

## 4. 역 목록 (stations)

열차 조회 시 사용 가능한 역 목록. Flutter `StationSelector` 위젯에서 드롭다운/자동완성에 사용한다.

```
서울, 용산, 광명, 수원, 천안아산, 오송, 대전, 김천구미,
동대구, 경주, 울산, 부산, 밀양, 창원중앙, 마산,
익산, 정읍, 광주송정, 나주, 목포,
전주, 남원, 순천, 여수엑스포,
강릉, 만종, 둔내, 평창, 진부,
행신, 청량리, 상봉, 양평, 만종
```

---

## 5. Flutter API Client 연동 가이드

### 5.1 ApiClient 호출 예시

```dart
// 로그인
final response = await apiClient.post('/api/auth/login', data: {
  'korail_id': id,
  'korail_pw': pw,
});

// 열차 조회
final response = await apiClient.get('/api/trains/search', queryParameters: {
  'dep': '서울',
  'arr': '부산',
  'date': '20260205',
  'time': '090000',
});

// 예약
final response = await apiClient.post('/api/reservation', data: {
  'train_no': 'KTX-101',
  'seat_type': 'general',
});

// 예약 조회
final response = await apiClient.get('/api/reservation/R20260202001');
```

### 5.2 TrainRepository 에러 처리 예시

```dart
class TrainRepository {
  Future<List<Train>> searchTrains(SearchCondition condition) async {
    try {
      final response = await _apiClient.get('/api/trains/search',
        queryParameters: {
          'dep': condition.depStation,
          'arr': condition.arrStation,
          'date': condition.date,
          'time': condition.time,
        },
      );
      final data = response.data;
      return (data['trains'] as List)
          .map((json) => Train.fromJson(json))
          .toList();
    } on DioException catch (e) {
      final errorBody = e.response?.data;
      final code = errorBody?['code'] ?? 'UNKNOWN';

      switch (code) {
        case 'SEARCH_001':
          throw InvalidParamsException(errorBody['detail']);
        case 'SEARCH_002':
          throw NoTrainsException();
        case 'SEARCH_003':
          throw KorailServerException();
        case 'AUTH_003':
          throw SessionExpiredException();
        default:
          throw UnknownApiException(e.message ?? '알 수 없는 오류');
      }
    }
  }
}
```

---

## 6. Backend 실행 가이드

### 6.1 환경 설정

```bash
# 1. 가상 환경 생성 및 활성화
cd backend
python -m venv venv
source venv/bin/activate      # macOS/Linux
# venv\Scripts\activate       # Windows

# 2. 의존성 설치
pip install -r requirements.txt

# 3. 환경 변수 설정
cp .env.example .env
# .env 파일에 코레일 계정 정보 입력
```

### 6.2 서버 실행

```bash
# 개발 모드 (자동 리로드)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 프로덕션 모드
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 6.3 API 문서 확인

FastAPI 자동 생성 문서:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## 7. 의존성 목록

### 7.1 Flutter (pubspec.yaml에 추가할 의존성)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  dio: ^5.4.0                    # HTTP 클라이언트
  flutter_riverpod: ^2.4.0       # 상태 관리 (MVVM ViewModel 역할)
  go_router: ^14.0.0             # 선언적 네비게이션
  intl: ^0.19.0                  # 날짜/시간 포맷팅
  freezed_annotation: ^2.4.0     # 불변 모델 어노테이션 (런타임)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  freezed: ^2.4.0                # 불변 모델 코드 생성기 (빌드타임)
  build_runner: ^2.4.0           # 코드 생성 빌드 러너
  json_serializable: ^6.7.0      # JSON 직렬화/역직렬화 코드 생성
```

코드 생성 실행 명령:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 7.2 Python Backend (requirements.txt)

```
fastapi>=0.109.0
uvicorn>=0.27.0
korail2>=0.1.0
python-dotenv>=1.0.0
pydantic>=2.5.0
```

| 패키지 | 용도 |
|--------|------|
| fastapi | REST API 프레임워크 |
| uvicorn | ASGI 서버 (FastAPI 실행) |
| korail2 | 코레일 비공식 API 래퍼 (로그인, 조회, 예약) |
| python-dotenv | .env 파일에서 환경 변수 로드 |
| pydantic | 요청/응답 데이터 검증 (FastAPI 내장 연동) |
