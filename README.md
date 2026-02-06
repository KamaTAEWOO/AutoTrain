# Auto KTX

KTX / SRT 열차 자동 예약 앱

## 주요 기능

- **KTX + SRT 듀얼 지원** — 하나의 앱에서 코레일(KTX)과 SRT 모두 예약
- **자동 예약** — 원하는 열차를 선택하면 빈 좌석이 생길 때까지 자동 반복 조회 후 즉시 예약
- **전체 열차 조회** — 하루 전체 열차를 한 번에 조회 (코레일 10개씩 페이징 자동 처리)
- **복수 열차 선택** — 여러 열차를 동시에 모니터링하여 먼저 빈 좌석이 나오는 열차 예약
- **자동 로그인** — 자격증명 암호화 저장, 세션 만료 시 자동 재로그인
- **백그라운드 모니터링** — 앱이 백그라운드에 있어도 예약 시도 지속

## 아키텍처

```
Flutter + Riverpod (StateNotifierProvider)
├── Core
│   ├── RailType enum (KTX/SRT 분기)
│   ├── RailColors (브랜드 색상)
│   └── Stations (역 목록)
├── Data
│   ├── TrainApiService (공통 인터페이스)
│   │   ├── KorailApi (코레일 직접 API)
│   │   └── SrtApi (SRT 직접 API + NetFunnel)
│   ├── TrainRepository (API 선택 + 세션 관리)
│   └── ApiClient (자격증명 저장)
└── Presentation
    ├── Providers (auth, search, monitor, reservation)
    └── Screens (login, home, train_list, my_reservation)
```

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.x |
| 상태 관리 | Riverpod |
| 라우팅 | GoRouter |
| HTTP | Dio + CookieJar |
| 보안 저장소 | FlutterSecureStorage |
| 암호화 | AES-256-CBC (코레일 비밀번호) |

## 빌드

```bash
# 의존성 설치
flutter pub get

# iOS 빌드
flutter build ios --no-codesign

# Android 빌드
flutter build apk
```

## 프로젝트 구조

```
lib/
├── app.dart                          # 앱 루트 위젯
├── router.dart                       # GoRouter 설정
├── core/
│   ├── constants/
│   │   ├── rail_type.dart            # KTX/SRT enum
│   │   ├── stations.dart             # 역 목록
│   │   └── app_enums.dart            # 좌석 타입 등
│   └── theme/
│       ├── app_theme.dart            # Material 테마
│       ├── rail_colors.dart          # KTX(파랑)/SRT(보라) 색상
│       └── korail_colors.dart        # 시맨틱 색상
├── data/
│   ├── models/
│   │   ├── train.dart                # 공통 열차 모델
│   │   ├── korail_train.dart         # 코레일 내부 모델
│   │   ├── srt_train.dart            # SRT 내부 모델
│   │   ├── reservation.dart          # 예약 모델
│   │   └── search_condition.dart     # 검색 조건
│   ├── services/
│   │   ├── train_api_service.dart    # 공통 API 인터페이스
│   │   ├── korail_api.dart           # 코레일 API 클라이언트
│   │   ├── korail_constants.dart     # 코레일 상수
│   │   ├── korail_crypto.dart        # 비밀번호 암호화
│   │   ├── srt_api.dart              # SRT API 클라이언트
│   │   ├── srt_constants.dart        # SRT 상수
│   │   ├── srt_netfunnel.dart        # SRT 대기열 관리
│   │   └── api_client.dart           # 자격증명 저장
│   └── repositories/
│       └── train_repository.dart     # 통합 Repository
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart        # 인증 상태
    │   ├── search_provider.dart      # 검색 조건
    │   ├── monitor_provider.dart     # 자동예약 모니터
    │   └── reservation_provider.dart # 예약 상태
    ├── screens/
    │   ├── login_screen.dart         # KTX/SRT 탭 로그인
    │   ├── home_screen.dart          # 검색 조건 입력
    │   ├── train_list_screen.dart    # 열차 목록/선택
    │   └── my_reservation_screen.dart # 예약 목록/취소
    └── widgets/
        ├── station_selector.dart     # 역 선택 위젯
        ├── station_picker_sheet.dart # 역 검색 바텀시트
        ├── train_card.dart           # 열차 카드
        └── horizontal_date_picker.dart # 날짜 선택
```
