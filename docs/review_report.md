# KTX 자동 조회/예약 테스트 앱 -- 코드 리뷰 리포트

> 리뷰 일자: 2026-02-02
> 리뷰어: Claude Opus 4.5 (코드 리뷰어 + 테크리드 에이전트)
> 대상: Flutter Frontend (`lib/`) + Python Backend (`backend/`)

---

## 1. 요약

| 항목 | 평가 |
|------|------|
| **전체 평가** | 구조적으로 잘 설계된 프로젝트. MVVM + Riverpod 패턴과 FastAPI 패턴 모두 충실히 준수하고 있으며, 계층 분리가 명확하다. 몇 가지 보안 이슈와 메모리 관련 개선점을 제외하면 프로덕션 수준의 코드 품질을 갖추고 있다. |
| **코드 품질 점수** | **82 / 100** |

**점수 산출 근거:**
- 아키텍처 설계 (25/25): 계층 분리, 패턴 준수, 에러 체계 모두 우수
- 코드 품질 (20/25): 명명 규칙 일관성, 문서화 우수하나 일부 코드 냄새 존재
- 보안 (15/20): .env 보호 미흡, 메모리 내 자격 증명 보관 우려
- 성능/안정성 (12/15): Timer lifecycle 잘 관리되나 메모리 누수 가능 지점 존재
- 테스트 (10/15): smoke test만 존재, 단위/통합 테스트 부재

---

## 2. 잘된 점 (Strengths)

### 2.1 아키텍처 설계가 명확하다

```
lib/
  core/          -- 설정, 상수, 테마 (외부 의존 없음)
  data/          -- 모델, 서비스, 리포지토리 (core만 참조)
  presentation/  -- Provider, Screen, Widget (data/core 참조)
```

`core -> data -> presentation` 방향의 단방향 의존성이 정확히 지켜지고 있다. 어떤 presentation 파일도 core를 우회하여 직접 외부 라이브러리에 의존하지 않고, data 계층이 presentation의 세부 사항을 알지 못한다.

### 2.2 에러 처리 체계가 잘 정립되어 있다

**Frontend (Dart):**
- `ApiError`: Backend에서 오는 구조화된 에러 (error/code/detail 3항목)
- `NetworkError`: 네트워크 연결 자체 오류
- `TrainRepository._handleError()`: DioException을 ApiError 또는 NetworkError로 분류하는 단일 진입점

**Backend (Python):**
- `KorailServiceError` 기본 예외 클래스에서 파생된 구체적 예외 계층:
  `LoginFailedError`, `AccountBlockedError`, `SessionExpiredError`, `NoTrainsError`, `KorailServerError`, `SoldOutError`, `ReservationNotFoundError`
- 모든 예외가 `{error, code, detail}` 표준 포맷으로 응답
- 글로벌 예외 핸들러(`main.py`)가 누락된 에러도 표준 포맷으로 변환

이 설계 덕분에 FE에서 `ApiError.isSessionExpired`, `ApiError.isSoldOut` 등으로 에러 유형을 쉽게 판별할 수 있다.

### 2.3 Timer lifecycle 관리가 올바르다

`MonitorNotifier`에서:
- `WidgetsBindingObserver`를 통해 앱 백그라운드 전환 시 타이머 일시 정지 (`_pauseTimer`)
- 포그라운드 복귀 시 타이머 재개 (`_resumeTimer`)
- `dispose()` 시 `_stopTimer()` + `removeObserver()` 호출
- 모니터링 시작 전 이전 타이머 정리 (`_stopTimer()`)

```dart
// monitor_provider.dart:371-376
@override
void dispose() {
  _stopTimer();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

### 2.4 Mock 모드 설계가 실용적이다

`AppEnvironment.useMock` 플래그 하나로 Backend 없이도 전체 앱 흐름을 테스트할 수 있다. `TrainRepository`에서 Mock/실제 API를 분기하는 방식이 깔끔하며, Mock 데이터도 시간 기반 랜덤(`now.second % 5`)으로 다양한 시나리오를 생성한다.

### 2.5 Pydantic 모델과 FastAPI 스키마가 잘 정의되어 있다

- `models/schemas.py`에 모든 요청/응답 모델이 `Field(description=...)`과 함께 문서화
- FastAPI의 `response_model`과 `responses` 파라미터가 모든 라우트에 설정
- Swagger UI (`/docs`)와 ReDoc (`/redoc`) 자동 문서화 지원

### 2.6 코드 문서화 수준이 높다

- Dart: 모든 public 클래스/메서드에 `///` doc comment
- Python: 모든 함수에 docstring (Args, Returns, Raises 포함)
- 한국어 주석이 일관되게 사용됨

### 2.7 Exponential Backoff 구현이 정확하다

`retry_service.py`의 backoff 스케줄(`base_delay * 2^attempt`, `max_delay` cap)이 올바르게 구현되어 있으며, 데코레이터/함수형 두 가지 인터페이스를 제공한다. 재시도 불가능 예외와 최대 재시도 횟수 초과 시 즉시 raise하는 로직도 정확하다.

---

## 3. 개선 필요 사항 (Issues)

### Critical (즉시 수정 필요)

#### C-1. 루트 `.gitignore`에 `.env` 미포함

**파일:** `/Users/impl/flutterWork/auto_ktx/.gitignore`

루트 `.gitignore`에 `.env` 패턴이 없다. `backend/.gitignore`에는 `.env`가 포함되어 있지만, 루트에 `.env` 파일이 생성되거나 `backend/` 외부에 환경 파일이 놓이면 Git에 커밋될 위험이 있다.

```
# 현재 루트 .gitignore: .env 관련 항목 없음
# backend/.gitignore에만 .env가 있음
```

**권장:** 루트 `.gitignore`에 다음을 추가:
```
.env
.env.*
!.env.example
```

#### C-2. ApiClient가 메모리에 자격 증명을 평문 보관

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/data/services/api_client.dart` (Line 18-19)

```dart
String? _savedKorailId;
String? _savedKorailPw;
```

자동 재로그인을 위해 코레일 아이디/비밀번호를 싱글톤 인스턴스의 필드에 평문으로 보관한다. 앱 메모리 덤프나 디버그 빌드에서 노출 위험이 있다.

**권장:** `flutter_secure_storage` 등을 활용하여 안전한 저장소에 암호화하여 보관하거나, 최소한 세션 토큰만 보관하고 자격 증명은 즉시 폐기.

#### C-3. Backend CORS 설정이 전체 오리진 허용

**파일:** `/Users/impl/flutterWork/auto_ktx/backend/main.py` (Line 57-63)

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # 개발 환경: 전체 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

`allow_origins=["*"]`와 `allow_credentials=True`를 동시에 설정하는 것은 보안상 위험하다. CORS 사양에 따르면 `credentials: true`일 때 `Access-Control-Allow-Origin: *`는 브라우저에서 차단되지만, 비-브라우저 클라이언트는 영향이 없으므로 서버 사이드에서 명시적으로 오리진을 제한해야 한다.

**권장:** 환경 변수로 허용 오리진을 설정:
```python
allowed_origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
```

---

### Major (개선 권장)

#### M-1. StationSelector에서 Listener 누적 등록 (메모리 누수)

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/widgets/station_selector.dart` (Line 128-133)

```dart
// fieldViewBuilder 내부 -- 빌드될 때마다 호출됨
controller.addListener(() {
  if (fieldController.text != controller.text) {
    fieldController.text = controller.text;
  }
});
```

`fieldViewBuilder`는 위젯이 리빌드될 때마다 호출되는데, 그때마다 `addListener`가 새 리스너를 추가한다. 이전 리스너가 제거되지 않으므로 리빌드 횟수에 비례하여 리스너가 누적된다.

**권장:** `initState`에서 한 번만 리스너를 등록하거나, `fieldViewBuilder` 바깥에서 리스너를 관리하여 중복 등록을 방지.

#### M-2. FE/BE 간 역 목록 불일치

**Flutter 측** (`lib/core/constants/stations.dart`): 39개 역 (포항 포함)
**Backend 측** (`backend/api/routes/trains.py`): 33개 역 (포항 미포함)

```dart
// Flutter에만 존재하는 역:
// '포항'
```

```python
# Backend VALID_STATIONS에 누락된 역:
# "포항"
```

Flutter 앱에서 "포항"을 선택하여 조회하면 Backend에서 `SEARCH_001` (유효하지 않은 역명) 에러가 반환된다.

**권장:** 역 목록을 단일 소스(예: 공유 JSON 또는 Backend API)에서 관리하여 동기화.

#### M-3. `@app.on_event` 사용 (FastAPI Deprecated)

**파일:** `/Users/impl/flutterWork/auto_ktx/backend/main.py` (Line 167, 177)

```python
@app.on_event("startup")
async def startup_event():
    ...

@app.on_event("shutdown")
async def shutdown_event():
    ...
```

`on_event` 데코레이터는 FastAPI 0.93.0+ 에서 deprecated되었다.

**권장:** `lifespan` context manager 사용:
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    yield
    # shutdown

app = FastAPI(lifespan=lifespan, ...)
```

#### M-4. MonitorNotifier에서 ref.read 사용 -- Provider 간 결합 강화

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/providers/monitor_provider.dart` (Line 382-391)

```dart
final monitorProvider =
    StateNotifierProvider<MonitorNotifier, MonitorState>((ref) {
  final logNotifier = ref.read(logProvider.notifier);
  final reservationNotifier = ref.read(reservationProvider.notifier);
  return MonitorNotifier(
    repository: TrainRepository(),
    logNotifier: logNotifier,
    reservationNotifier: reservationNotifier,
  );
});
```

`ref.read`로 다른 Notifier의 인스턴스를 직접 가져와 생성자에 주입한다. 이는 Provider 간 강한 결합을 만들며, Notifier가 dispose/재생성될 때 stale 참조가 발생할 수 있다.

**권장:** `ref.watch`를 사용하거나, Riverpod의 `ref`를 Notifier 내부에 전달하여 필요 시 읽도록 변경.

#### M-5. Backend에서 세션 토큰 검증이 불완전

**파일:** `/Users/impl/flutterWork/auto_ktx/backend/api/deps.py` (Line 29-84)

`verify_session`에서 Bearer 토큰을 추출하지만, **토큰 값 자체를 검증하지 않는다**. `KorailService.is_session_valid()`는 시간 만료만 확인하고, 실제 토큰 값이 서버가 발급한 것과 일치하는지 비교하지 않는다.

```python
# 토큰 값 비교 없이 세션 유효 시간만 확인
if not service.is_session_valid():
    raise HTTPException(...)
```

임의의 문자열을 Bearer 토큰으로 보내도, 세션이 아직 유효하면 인증이 통과된다.

**권장:** `verify_session`에서 추출한 토큰과 `service._session_token`을 비교하는 로직 추가.

#### M-6. `print` 문을 로깅 프레임워크로 교체 필요

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/data/services/api_client.dart` (Line 44, 49, 54)

```dart
// ignore: avoid_print
print('[API] ${options.method} ${options.path}');
```

`print`는 릴리즈 빌드에서도 출력되며, 성능에 영향을 줄 수 있다. `// ignore: avoid_print` 주석으로 lint를 무시하고 있다.

**권장:** `dart:developer`의 `log()` 또는 `logger` 패키지를 사용하여 릴리즈 빌드에서는 로그가 출력되지 않도록 제어.

#### M-7. `intl` 패키지가 선언되었으나 사용되지 않음

**파일:** `/Users/impl/flutterWork/auto_ktx/pubspec.yaml` (Line 37)

```yaml
intl: ^0.19.0
```

`lib/` 전체에서 `import 'package:intl/...'` 가 한 건도 없다. 날짜/시간 포맷팅을 수동으로 하고 있어 `intl`이 불필요하거나, 아직 적용하지 않은 것이다.

**권장:** 사용하지 않으면 의존성에서 제거. 날짜/시간 포맷팅에 활용할 계획이면 수동 포맷 로직을 `intl`의 `DateFormat`으로 교체.

#### M-8. GoRouter가 단일 라우트만 사용 -- 과도한 의존성

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/router.dart`

```dart
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
  ],
);
```

GoRouter를 도입했지만 라우트가 `/` 하나뿐이며, 실제 탭 전환은 `IndexedStack` + `onTabChange` 콜백으로 처리한다. GoRouter의 `ShellRoute`나 `StatefulShellRoute`를 사용하지 않고 있다.

**권장:** GoRouter를 제거하고 `MaterialApp`을 사용하거나, 탭 전환을 GoRouter의 `StatefulShellRoute`로 마이그레이션하여 URL 기반 탭 관리를 활용.

---

### Minor (참고)

#### m-1. `result_screen.dart`에서 Reservation 타입이 `dynamic`으로 선언

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/screens/result_screen.dart` (Line 87, 226)

```dart
Widget _buildSuccessResult(
  BuildContext context,
  WidgetRef ref,
  dynamic reservation,  // Reservation 타입이어야 함
  List logs,
)
```

`_buildSuccessResult`와 `_buildFailureResult`의 `reservation` 파라미터가 `dynamic`으로 선언되어 컴파일 타임 타입 체크가 불가능하다.

**권장:** `Reservation` 타입으로 명시 변경.

#### m-2. `LogTile`에서 magic string 사용

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/widgets/log_tile.dart` (Line 74-87, 90-100)

```dart
case 'search':
case 'reserve':
case 'login':
case 'error':
```

액션과 결과 타입이 문자열 리터럴로 비교되고 있다. Enum이나 상수로 정의하면 오타 방지 및 자동완성이 가능하다.

#### m-3. `TrainCard._calculateDuration()`의 자정 넘기기 미처리

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/widgets/train_card.dart` (Line 172-195)

```dart
final diff = arrMinutes - depMinutes;
if (diff <= 0) return '';  // 자정 넘기는 경우 빈 문자열 반환
```

도착 시간이 자정을 넘기는 경우(예: 출발 23:00, 도착 01:00) 음수가 되어 빈 문자열을 반환한다. 실제 KTX에는 드문 경우이지만 처리되면 좋다.

#### m-4. `SearchCondition`에 `==` 연산자와 `hashCode` 미구현

데이터 모델 클래스들(`Train`, `SearchCondition`, `Reservation`, `LogEntry`)에 `==` 연산자와 `hashCode`가 구현되지 않았다. Riverpod 상태 비교 시 참조 비교만 이루어져, 동일 값의 새 인스턴스가 항상 상태 변경으로 감지된다.

**권장:** `freezed` 패키지 도입 또는 `Equatable` mixin 사용.

#### m-5. `MonitorScreen`이 build 시마다 `onTabChange`를 재등록

**파일:** `/Users/impl/flutterWork/auto_ktx/lib/presentation/screens/monitor_screen.dart` (Line 23-24)

```dart
final monitorNotifier = ref.read(monitorProvider.notifier);
monitorNotifier.onTabChange = onTabChange;
```

`build()` 메서드 안에서 매 리빌드마다 콜백을 재등록한다. 기능상 문제는 없지만 side-effect를 build 안에서 수행하는 것은 Flutter 안티패턴이다.

#### m-6. Backend `korail_service.py`의 `reserve()` 메서드에서 `_last_dep` 등 미정의 속성 참조

**파일:** `/Users/impl/flutterWork/auto_ktx/backend/services/korail_service.py` (Line 309-313)

```python
trains = self._korail.search_train_allday(
    getattr(self, "_last_dep", "서울"),
    getattr(self, "_last_arr", "부산"),
    ...
)
```

`_last_dep`, `_last_arr`, `_last_date`, `_last_time`은 `__init__`이나 `search_trains`에서 설정되지 않는다. 항상 기본값("서울", "부산")으로 fallback되므로, 마지막 검색 조건과 무관한 열차를 조회할 수 있다.

**권장:** `search_trains` 호출 시 마지막 검색 조건을 인스턴스 변수에 저장.

---

## 4. 보안 체크리스트

| # | 항목 | 상태 | 비고 |
|---|------|------|------|
| 1 | `.env` 파일이 `.gitignore`에 포함 | **WARN** | `backend/.gitignore`에만 포함, 루트 `.gitignore`에는 미포함 (C-1) |
| 2 | `.env.example`이 제공됨 | PASS | `backend/.env.example` 존재, 실제 값 없음 |
| 3 | 하드코딩된 credentials 없음 | PASS | 코드에 실제 아이디/비밀번호 하드코딩 없음 |
| 4 | API 키가 코드에 노출되지 않음 | PASS | API 키 사용 없음 |
| 5 | 세션 토큰이 안전하게 관리됨 | **WARN** | 메모리 내 평문 보관 (C-2), 토큰 값 미검증 (M-5) |
| 6 | CORS 설정이 적절함 | **FAIL** | `allow_origins=["*"]` + `allow_credentials=True` (C-3) |
| 7 | 비밀번호가 로그에 노출되지 않음 | PASS | 로그인 시 ID 앞 3자만 마스킹 (`[:3] + "***"`) |
| 8 | HTTPS 사용 | **WARN** | 개발 환경에서 HTTP 사용 중 (localhost:8000). 배포 시 HTTPS 적용 필요 |
| 9 | 입력값 검증 | PASS | Backend에서 역명, 날짜, 시간 형식 모두 검증 |
| 10 | 에러 메시지에 내부 정보 미노출 | **WARN** | `KorailServerError`에 원본 예외 메시지 포함 가능 (`f"코레일 서버 연결 실패: {str(e)}"`) |

---

## 5. 아키텍처 평가

### 5.1 계층 구조 (점수: 9/10)

```
Flutter App                          Python Backend
==============                       ==============
presentation/                        api/routes/
  screens/  -- UI 화면                  auth.py, trains.py, reservation.py
  providers/ -- 상태 관리              api/
  widgets/  -- 재사용 컴포넌트           deps.py  -- DI, 세션 검증
data/                                services/
  models/   -- 데이터 모델               korail_service.py  -- 비즈니스 로직
  services/ -- HTTP 클라이언트            retry_service.py   -- 재시도 유틸
  repositories/ -- 데이터 접근         models/
core/                                  schemas.py  -- Pydantic 모델
  config/   -- 환경 설정
  constants/ -- 상수
  theme/    -- 테마
```

**강점:**
- FE와 BE 모두 3-Layer 아키텍처를 준수
- FE: core -> data -> presentation 단방향 의존
- BE: schemas -> services -> api 단방향 의존
- 관심사 분리가 명확 (UI / 상태 / 데이터 / 네트워크)

**약점:**
- `TrainRepository`에 `LoginResponse` 모델이 인라인으로 정의됨 (별도 파일이 아님)
- GoRouter 활용이 미흡 (단일 라우트)

### 5.2 FE/BE API 스펙 일치 여부 (점수: 8/10)

| 엔드포인트 | FE 경로 | BE 경로 | 일치 |
|-----------|--------|--------|------|
| 로그인 | `POST /api/auth/login` | `POST /api/auth/login` | PASS |
| 열차 조회 | `GET /api/trains/search` | `GET /api/trains/search` | PASS |
| 예약 | `POST /api/reservation` | `POST /api/reservation` | PASS |

| 데이터 필드 | FE (Dart) | BE (Pydantic) | 일치 |
|------------|-----------|---------------|------|
| 열차 번호 | `train_no` | `train_no` | PASS |
| 열차 종류 | `train_type` | `train_type` | PASS |
| 출발역 | `dep_station` | `dep_station` | PASS |
| 도착역 | `arr_station` | `arr_station` | PASS |
| 출발 시간 | `dep_time` | `dep_time` | PASS |
| 도착 시간 | `arr_time` | `arr_time` | PASS |
| 일반실 좌석 | `general_seats` | `general_seats` | PASS |
| 특실 좌석 | `special_seats` | `special_seats` | PASS |
| 세션 토큰 | `session_token` | `session_token` | PASS |
| 예약 번호 | `reservation_id` | `reservation_id` | PASS |

| 에러 포맷 | FE 파싱 | BE 응답 | 일치 |
|----------|--------|--------|------|
| HTTPException 래핑 | `{"detail": {"error":..., "code":..., "detail":...}}` | 동일 | PASS |
| 직접 반환 | `{"error":..., "code":..., "detail":...}` | 글로벌 핸들러에서 사용 | PASS |

**불일치 사항:**
- 역 목록: FE 39개 vs BE 33개 (포항 불일치 - M-2)
- BE의 `TrainSearchResponse`에는 `searched_at` 필드가 있으나, FE에서는 이를 사용하지 않음 (문제 아님)

### 5.3 에러 코드 체계 (점수: 9/10)

```
AUTH_001  -- 로그인 실패       (401)
AUTH_002  -- 계정 차단         (403)
AUTH_003  -- 세션 만료         (401)
SEARCH_001 -- 잘못된 파라미터  (400)
SEARCH_002 -- 열차 없음       (404)
SEARCH_003 -- 코레일 서버 오류 (503)
RESERVE_001 -- 매진           (409)
RESERVE_002 -- 세션 만료       (401)
RESERVE_003 -- 예약 없음      (404)
SYSTEM_001 -- 내부 서버 오류   (500)
SYSTEM_002 -- 코레일 서버 오류 (503)
SYSTEM_003 -- 요청 시간 초과   (504)
```

카테고리(AUTH/SEARCH/RESERVE/SYSTEM) + 3자리 숫자 체계가 일관되며, FE의 `ApiError.category` getter로 카테고리별 분류가 가능하다.

**약간의 중복:** `AUTH_003`과 `RESERVE_002`가 모두 "세션 만료"를 의미한다. 컨텍스트(인증/예약)에 따라 구분한 것으로 보이나, 통합도 고려할 만하다.

### 5.4 상태 관리 패턴 (점수: 8/10)

| Provider | 상태 클래스 | Notifier 클래스 | 평가 |
|----------|-----------|----------------|------|
| `searchProvider` | `SearchState` | `SearchNotifier` | 깔끔한 copyWith 패턴 |
| `monitorProvider` | `MonitorState` | `MonitorNotifier` | Timer + WidgetsBindingObserver 통합 |
| `logProvider` | `List<LogEntry>` | `LogNotifier` | 단순 리스트, 최대 500건 제한 |
| `reservationProvider` | `ReservationState` | `ReservationNotifier` | 단순 결과 보관 |

모든 Provider가 `StateNotifierProvider`를 사용하며 불변 상태 + copyWith 패턴을 따른다.

---

## 6. 성능 점검

### 6.1 불필요한 위젯 리빌드 가능성

| 위치 | 문제 | 심각도 |
|------|------|--------|
| `MonitorScreen.build()` (Line 23-24) | `ref.read(monitorProvider.notifier)`로 side-effect 수행 | Low |
| `SearchScreen.build()` | `ref.watch(searchProvider)` 전체 상태 구독 -- 어떤 필드 변경이든 전체 리빌드 | Low |
| `ResultScreen.build()` | `ref.watch(logProvider)` -- 로그 추가될 때마다 결과 화면도 리빌드 | Medium |

`ResultScreen`은 로그 목록이 `ExpansionTile` 안에 있어 화면에 보이지 않을 때도 로그 변경 시 전체가 리빌드된다. `select`를 사용하여 필요한 필드만 구독하면 개선된다.

### 6.2 메모리 관련

| 위치 | 문제 | 심각도 |
|------|------|--------|
| `StationSelector.fieldViewBuilder` | `addListener` 누적 등록 (M-1) | High |
| `IndexedStack` | 3개 탭 모두 메모리에 유지 | Low (의도적) |
| `LogNotifier` | 최대 500건 제한으로 무한 증가 방지 | OK |

### 6.3 API 호출 최적화

- Timer.periodic 기반 반복 조회: 조건에 따라 5~30초 주기로 호출 -- 적절
- 백그라운드 전환 시 타이머 일시 정지 -- 불필요한 호출 방지
- 좌석 발견 시 즉시 타이머 중지 후 예약 시도 -- 중복 조회 방지

---

## 7. 테스트 현황

| 영역 | 파일 | 테스트 수 | 커버리지 |
|------|------|----------|---------|
| Flutter Widget | `test/widget_test.dart` | 6 | 앱 로드, 탭 전환 smoke test |
| Flutter Unit | - | 0 | Provider, Repository 단위 테스트 없음 |
| Backend Unit | - | 0 | Service, Route 단위 테스트 없음 |
| Backend Integration | - | 0 | API 통합 테스트 없음 |

**권장 추가 테스트:**
1. `TrainRepository` Mock 모드 단위 테스트
2. `MonitorNotifier` 상태 전이 테스트 (idle -> searching -> found -> reserving -> success)
3. `ApiError.fromResponseBody` 파싱 테스트 (다양한 에러 포맷)
4. Backend: `pytest` + `httpx.AsyncClient`로 각 엔드포인트 테스트
5. Backend: `KorailService` 예외 처리 단위 테스트

---

## 8. 결론 및 권장사항

### 즉시 조치 (1-2일)
1. **루트 `.gitignore`에 `.env` 추가** -- 자격 증명 유출 방지 (C-1)
2. **CORS 오리진 제한** -- 환경 변수 기반으로 변경 (C-3)
3. **`StationSelector` 리스너 누적 수정** -- 메모리 누수 방지 (M-1)

### 단기 개선 (1주)
4. **FE/BE 역 목록 동기화** -- "포항" 추가 또는 단일 소스 관리 (M-2)
5. **세션 토큰 검증 강화** -- 토큰 값 비교 로직 추가 (M-5)
6. **`print` -> 로깅 프레임워크** 교체 (M-6)
7. **`result_screen.dart` `dynamic` -> `Reservation`** 타입 변경 (m-1)
8. **Backend `_last_dep` 등 누락 속성** 수정 (m-6)

### 중기 개선 (2-4주)
9. **단위 테스트 추가** -- Flutter Provider/Repository + Backend Service/Route
10. **`flutter_secure_storage`** 도입하여 자격 증명 암호화 보관 (C-2)
11. **`on_event` -> `lifespan`** 마이그레이션 (M-3)
12. **GoRouter 활용 확대** 또는 제거 (M-8)
13. **`freezed` 또는 `Equatable`** 도입으로 모델 동등성 비교 개선 (m-4)

### 장기 개선
14. 다크 테마 지원 (`AppTheme.darkTheme` 추가)
15. 로컬 알림 -- 예약 성공 시 푸시 알림
16. 앱 상태 영속화 (로그, 마지막 검색 조건 등)
17. CI/CD 파이프라인 구축 (테스트 자동화, 린트 체크)

---

## 부록: 파일 목록 요약

### Flutter (`lib/`) -- 19 파일
```
lib/main.dart
lib/app.dart
lib/router.dart
lib/core/config/app_environment.dart
lib/core/constants/api_config.dart
lib/core/constants/app_enums.dart
lib/core/constants/stations.dart
lib/core/theme/app_theme.dart
lib/data/models/api_error.dart
lib/data/models/log_entry.dart
lib/data/models/reservation.dart
lib/data/models/search_condition.dart
lib/data/models/train.dart
lib/data/repositories/train_repository.dart
lib/data/services/api_client.dart
lib/presentation/providers/log_provider.dart
lib/presentation/providers/monitor_provider.dart
lib/presentation/providers/reservation_provider.dart
lib/presentation/providers/search_provider.dart
lib/presentation/screens/monitor_screen.dart
lib/presentation/screens/result_screen.dart
lib/presentation/screens/search_screen.dart
lib/presentation/widgets/log_tile.dart
lib/presentation/widgets/station_selector.dart
lib/presentation/widgets/status_badge.dart
lib/presentation/widgets/train_card.dart
```

### Backend (`backend/`) -- 9 파일
```
backend/main.py
backend/models/schemas.py
backend/services/korail_service.py
backend/services/retry_service.py
backend/api/deps.py
backend/api/routes/auth.py
backend/api/routes/trains.py
backend/api/routes/reservation.py
backend/.env.example
```

### 테스트 -- 1 파일
```
test/widget_test.dart
```
