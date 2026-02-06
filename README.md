# 🚂 AutoTrain - KTX 자동 조회/예약 학습 프로젝트

> ⚠️ **[중요] 이 프로젝트는 교육 및 학습 목적으로만 제작되었습니다.**
> 
> - 📚 **학습 목적**: Flutter, 비공식 API 활용, 자동화 기술 검증을 위한 스터디 프로젝트
> - 🚫 **배포 금지**: 절대로 프로덕션 환경에 배포하거나 상업적으로 사용하지 마십시오
> - 📖 **참고용**: 코드 구조, 아키텍처, API 통신 방법을 학습하는 용도로만 사용하세요
> - ⚖️ **책임 소재**: 본 프로젝트를 무단 배포하거나 악용하여 발생하는 모든 법적, 기술적 문제는 사용자 본인의 책임입니다
> - 🔒 **비공식 API**: 코레일 비공식 API를 사용하므로 언제든 작동이 중단될 수 있습니다
> - 🎓 **개인 학습**: 이 프로젝트는 개인 스터디를 위해 개발되었으며, 실제 서비스 운영을 위한 것이 아닙니다

---

## 📋 목차

- [프로젝트 개요](#-프로젝트-개요)
- [주요 기능](#-주요-기능)
- [기술 스택](#-기술-스택)
- [아키텍처](#-아키텍처)
- [프로젝트 구조](#-프로젝트-구조)
- [설치 및 실행](#-설치-및-실행)
- [주요 화면](#-주요-화면)
- [API 테스트 결과](#-api-테스트-결과)
- [학습 포인트](#-학습-포인트)
- [면책 조항](#-면책-조항)
- [라이선스](#-라이선스)

---

## 🎯 프로젝트 개요

**AutoTrain**은 KTX 열차 조회 및 예약 프로세스를 자동화하는 Flutter 기반 모바일 앱입니다.

### 개발 목적

- ✅ Flutter 크로스플랫폼 앱 개발 학습
- ✅ MVVM + Riverpod 상태관리 패턴 실습
- ✅ 코레일 비공식 API 연동 방법 연구
- ✅ 자동화 로직 (Timer, Background Service) 구현 학습
- ✅ AES-256-CBC 암호화 및 쿠키 기반 세션 관리 학습

### 주요 특징

- 🔄 **자동 열차 조회**: 설정한 조건으로 주기적 자동 조회
- 🎯 **조건 감시**: 좌석 발견 시 자동 예약 시도
- 📱 **크로스 플랫폼**: iOS/Android 지원
- 🔐 **보안**: AES-256 암호화, 세션 관리, 쿠키 처리
- 📊 **실시간 모니터링**: 조회 상태, 로그, 진행 상황 표시
- 🔔 **백그라운드 서비스**: 앱이 백그라운드에 있어도 조회 가능 (iOS/Android)

---

## ✨ 주요 기능

| 기능 | 설명 | 상태 |
|-----|------|------|
| 🔐 **로그인** | 코레일 계정 로그인 (회원번호/이메일/전화번호) | ✅ 완료 |
| 🔍 **열차 조회** | 출발/도착역, 날짜, 시간 기반 전체 열차 조회 | ✅ 완료 |
| 🔄 **자동 새로고침** | 설정된 주기(5~60초)로 자동 조회 | ✅ 완료 |
| 🎯 **조건 감시** | 좌석 발견 시 자동 예약 시도 | ✅ 완료 |
| 🎫 **예약 시도** | 일반실/특실 선택 예약 (결제 미포함) | ✅ 완료 |
| 📋 **예약 목록** | 내 예약 조회 및 관리 | ✅ 완료 |
| ❌ **예약 취소** | 예약 취소 기능 | ✅ 완료 |
| 📊 **실시간 로그** | 조회/예약 이력 실시간 표시 | ✅ 완료 |
| 🔔 **백그라운드 실행** | 앱 백그라운드에서도 자동 조회 | ✅ 완료 |
| 🔔 **로컬 알림** | 좌석 발견 시 푸시 알림 | ✅ 완료 |

---

## 🛠 기술 스택

### Frontend (Flutter)

| 카테고리 | 기술 | 버전 | 용도 |
|---------|------|------|------|
| **Framework** | Flutter | SDK ^3.9.2 | 크로스플랫폼 UI |
| **상태관리** | flutter_riverpod | ^2.4.0 | MVVM 패턴 |
| **HTTP 클라이언트** | dio | ^5.4.0 | REST API 통신 |
| **쿠키 관리** | dio_cookie_manager | ^3.1.1 | 쿠키 기반 세션 |
| **라우팅** | go_router | ^14.0.0 | 선언적 네비게이션 |
| **암호화** | encrypt | ^5.0.3 | AES-256-CBC |
| **로컬 저장소** | flutter_secure_storage | ^9.2.0 | 계정 정보 보안 저장 |
| **백그라운드** | flutter_background_service | ^5.0.0 | 백그라운드 작업 |
| **알림** | flutter_local_notifications | ^18.0.0 | 로컬 푸시 알림 |
| **권한** | permission_handler | ^11.0.0 | 알림 권한 관리 |

### 주요 의존성

```yaml
dependencies:
  flutter_riverpod: ^2.4.0           # 상태관리
  dio: ^5.4.0                        # HTTP 통신
  dio_cookie_manager: ^3.1.1         # 쿠키 처리
  cookie_jar: ^4.0.8                 # 쿠키 저장소
  encrypt: ^5.0.3                    # AES 암호화
  go_router: ^14.0.0                 # 라우팅
  flutter_secure_storage: ^9.2.0     # 보안 저장소
  flutter_background_service: ^5.0.0 # 백그라운드 서비스
  flutter_local_notifications: ^18.0.0 # 로컬 알림
```

---

## 🏗 아키텍처

### 전체 구조

```
┌──────────────────────────────┐
│   Flutter App (Client)       │
│   MVVM + Riverpod            │
│                              │
│  ┌────────────────────────┐  │
│  │  Presentation Layer    │  │
│  │  (Screens, Providers)  │  │
│  └──────────┬─────────────┘  │
│             │                │
│  ┌──────────▼─────────────┐  │
│  │  Data Layer            │  │
│  │  (Repository, API)     │  │
│  └──────────┬─────────────┘  │
│             │                │
│  ┌──────────▼─────────────┐  │
│  │  Core Layer            │  │
│  │  (Services, Utils)     │  │
│  └────────────────────────┘  │
│                              │
└──────────────┬───────────────┘
               │ HTTP/HTTPS
               │ (Dio + Cookie)
               ▼
┌──────────────────────────────┐
│   코레일 서버 (비공식 API)    │
│   - 암호화 키 발급            │
│   - 로그인 (AES-256)         │
│   - 열차 조회                │
│   - 예약/취소                │
└──────────────────────────────┘
```

### MVVM + Riverpod 패턴

```
View (Screen)
     ↕
ViewModel (Provider)
     ↕
Repository
     ↕
API Client (KorailApi)
     ↕
코레일 서버
```

### 통신 흐름

```
1. 암호화 키 획득
   App → POST /classes/com.korail.mobile.common.code.do
       → 암호화 키 (idx, key) 수신

2. 로그인
   App → 비밀번호 AES-256-CBC 암호화
       → POST /classes/com.korail.mobile.login.Login
       → 세션 쿠키 수신

3. 열차 조회
   App → GET /classes/com.korail.mobile.seatMovie.ScheduleView
       → 열차 목록 수신

4. 예약
   App → GET /classes/com.korail.mobile.reservation.ReservationSubmit
       → 예약 결과 수신
```

---

## 📁 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점
├── app.dart                           # MaterialApp + Router
├── router.dart                        # GoRouter 라우트 정의
│
├── core/                              # 앱 전역 공통 모듈
│   ├── config/
│   │   └── app_environment.dart       # 환경 설정
│   ├── constants/
│   │   ├── stations.dart              # KTX 역 목록
│   │   ├── api_config.dart            # API 설정
│   │   └── app_enums.dart             # Enum 정의
│   ├── services/
│   │   ├── background_service.dart    # 백그라운드 서비스
│   │   └── notification_service.dart  # 알림 서비스
│   └── theme/
│       ├── app_theme.dart             # 앱 테마
│       └── korail_colors.dart         # 코레일 색상
│
├── data/                              # 데이터 계층
│   ├── models/
│   │   ├── train.dart                 # 열차 모델
│   │   ├── korail_train.dart          # 코레일 내부 모델
│   │   ├── reservation.dart           # 예약 모델
│   │   ├── search_condition.dart      # 검색 조건 모델
│   │   ├── log_entry.dart             # 로그 모델
│   │   └── api_error.dart             # 에러 모델
│   ├── repositories/
│   │   └── train_repository.dart      # API 호출 추상화
│   └── services/
│       ├── api_client.dart            # Dio 기본 설정
│       ├── korail_api.dart            # 코레일 API 클라이언트
│       ├── korail_constants.dart      # API 상수
│       └── korail_crypto.dart         # AES-256 암호화
│
└── presentation/                      # UI 계층
    ├── screens/
    │   ├── home_screen.dart           # 홈 화면
    │   ├── login_screen.dart          # 로그인 화면
    │   ├── train_list_screen.dart     # 전체 열차 목록
    │   └── my_reservation_screen.dart # 내 예약 목록
    ├── widgets/
    │   ├── station_selector.dart      # 역 선택 위젯
    │   ├── station_picker_sheet.dart  # 역 선택 바텀시트
    │   ├── horizontal_date_picker.dart # 날짜 선택 위젯
    │   ├── train_card.dart            # 열차 카드
    │   ├── status_badge.dart          # 상태 배지
    │   ├── log_tile.dart              # 로그 타일
    │   └── train_loading_indicator.dart # 로딩 애니메이션
    └── providers/
        ├── auth_provider.dart         # 인증 상태
        ├── search_provider.dart       # 검색 상태
        ├── monitor_provider.dart      # 모니터링 상태
        ├── reservation_provider.dart  # 예약 상태
        └── log_provider.dart          # 로그 상태
```

---

## 🚀 설치 및 실행

### 사전 요구사항

- Flutter SDK ^3.9.2
- Dart SDK
- Android Studio / Xcode (iOS)
- 코레일 계정

### 1. 프로젝트 클론

```bash
git clone <repository-url>
cd AutoTrain
```

### 2. 의존성 설치

```bash
flutter pub get
```

### 3. 환경 설정

프로젝트는 **Mock 모드**와 **실제 API 모드**를 지원합니다.

**`lib/main.dart`에서 설정:**

```dart
// Mock 모드 (테스트용)
AppEnvironment.init(mock: true);

// 실제 API 모드
AppEnvironment.init(mock: false);
```

### 4. 실행

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# 특정 디바이스
flutter devices
flutter run -d <device-id>
```

### 5. 빌드

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

---

## 📱 주요 화면

### 1. 로그인 화면

- 코레일 회원번호/이메일/전화번호 입력
- 비밀번호 AES-256 암호화 후 로그인
- 세션 자동 관리

### 2. 홈 화면 (검색)

- 출발역/도착역 선택 (자동완성)
- 날짜/시간 선택 (Horizontal Date Picker)
- 자동 예약 토글
- 조회 주기 설정 (5~60초)
- 실시간 조회 결과 표시

### 3. 전체 열차 목록 화면

- 하루 전체 열차 조회 (최대 15회 반복)
- 좌석 상태 표시 (일반실/특실)
- 열차 상세 정보 (출발/도착 시간)
- 예약 버튼

### 4. 모니터링 화면

- 자동 조회 상태 실시간 표시
- 조회 횟수, 마지막 조회 시간
- 실시간 로그 (조회/예약 이력)
- 중지/재개 버튼

### 5. 내 예약 화면

- 예약 목록 조회
- 예약 상세 정보
- 예약 취소 기능

---

## 🧪 API 테스트 결과

**테스트 일시**: 2026-02-05
**테스트 환경**: Android (SM-G965N, Android 10)

| API | 상태 | 응답 | 비고 |
|-----|------|------|------|
| 암호화 키 획득 | ✅ PASS | 200 OK | idx: 83, 08 |
| 로그인 | ✅ PASS | 200 OK | strResult=SUCC |
| 예약 목록 조회 | ✅ PASS | 200 OK | 0건 (정상) |
| 열차 조회 (단일) | ✅ PASS | 200 OK | 10개 열차 반환 |
| 열차 조회 (전체) | ✅ PASS | 200 OK | 15회 반복 조회 |
| 예약 시도 | ⏳ 미테스트 | - | 예약 가능 기간 필요 |
| 예약 취소 | ⏳ 미테스트 | - | 예약 생성 후 테스트 |

### 해결된 주요 이슈

| 이슈 | 원인 | 해결 |
|-----|------|------|
| 암호화 키 파싱 오류 | 중첩 응답 구조 | `data['app.login.cphd']['key']` 탐색 |
| 승객수 오류 (WRP011002) | 파라미터명 언더스코어 | `txtPsgTpCd1` (언더스코어 제거) |
| 예약 취소 입력값 오류 | jrnyCnt 한 자리 | `'01'` (두 자리 패딩) |

---

## 📚 학습 포인트

### 1. Flutter 아키텍처

- ✅ **MVVM 패턴**: View - ViewModel(Provider) - Repository - API 분리
- ✅ **Riverpod 상태관리**: StateNotifier, FutureProvider 활용
- ✅ **GoRouter**: 선언적 라우팅, Deep Link

### 2. HTTP 통신

- ✅ **Dio 설정**: BaseOptions, Interceptor, Cookie 관리
- ✅ **에러 처리**: DioException → 커스텀 Exception 변환
- ✅ **세션 관리**: 쿠키 기반 세션 자동 관리

### 3. 보안

- ✅ **AES-256-CBC 암호화**: PKCS7 패딩, Base64 인코딩
- ✅ **SecureStorage**: 계정 정보 암호화 저장
- ✅ **세션 유효성 검사**: 자동 재로그인

### 4. 백그라운드 처리

- ✅ **Background Service**: iOS/Android 백그라운드 실행
- ✅ **Local Notification**: 좌석 발견 시 푸시 알림
- ✅ **WidgetsBindingObserver**: 앱 라이프사이클 관리

### 5. 비공식 API 연동

- ✅ **API 리버스 엔지니어링**: 코레일 모바일 API 분석
- ✅ **암호화 프로토콜**: 서버 키 기반 비밀번호 암호화
- ✅ **쿠키 기반 인증**: 세션 쿠키 관리

---

## ⚠️ 면책 조항

### 법적 고지

이 프로젝트는 **교육 및 학습 목적으로만** 개발되었습니다.

#### 사용 제한 사항

1. **비공식 API 사용**
   - 코레일 공식 API가 아닌 비공식 API를 사용합니다
   - 언제든 API가 변경되거나 차단될 수 있습니다
   - 코레일 서비스 약관을 위반할 수 있습니다

2. **배포 금지**
   - 앱 스토어(Google Play, App Store)에 배포 금지
   - 상업적 목적으로 사용 금지
   - 제3자에게 배포 금지

3. **개인 학습 용도**
   - 개인 학습 및 연구 목적으로만 사용하세요
   - 코드 구조와 아키텍처를 학습하는 참고 자료로 활용하세요
   - 실제 예약에 사용하지 마세요

4. **책임 소재**
   - 이 프로젝트를 사용하여 발생하는 모든 법적, 기술적 문제는 **사용자 본인의 책임**입니다
   - 계정 차단, 서비스 제한, 법적 분쟁 등의 책임은 사용자에게 있습니다
   - 프로젝트 개발자는 어떠한 책임도 지지 않습니다

5. **보안 경고**
   - 코레일 계정 정보를 신중하게 관리하세요
   - 타인에게 계정 정보를 공유하지 마세요
   - 공용 기기에서 사용하지 마세요

#### 권장 사항

- ✅ 코드 구조 학습용으로 활용하세요
- ✅ Flutter/Dart 개발 패턴 학습에 참고하세요
- ✅ API 통신 방법 학습에 활용하세요
- ❌ 실제 예약에 사용하지 마세요
- ❌ 상업적 목적으로 사용하지 마세요
- ❌ 배포하지 마세요

---

## 📄 라이선스

이 프로젝트는 **교육 및 학습 목적**으로만 사용할 수 있습니다.

```
Copyright (c) 2026 AutoTrain Study Project

이 소프트웨어는 교육 및 학습 목적으로만 사용할 수 있습니다.
상업적 사용, 배포, 수정 후 재배포를 금지합니다.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 문의

이 프로젝트는 개인 학습 프로젝트입니다.

**문의 사항이 있으시면**:
- 코드 구조나 아키텍처에 대한 질문만 받습니다
- 실제 사용이나 배포에 대한 문의는 받지 않습니다

---

## 📝 참고 문서

프로젝트의 상세 문서는 `docs/` 디렉토리에서 확인할 수 있습니다:

- [기능 명세서](docs/feature_spec.md)
- [아키텍처 설계](docs/architecture.md)
- [API 테스트 리포트](docs/api_test_report.md)
- [UI 명세서](docs/ui_spec.md)
- [API 명세서](docs/api_spec.md)

---

## 🙏 감사의 말

이 프로젝트는 Flutter, Dart, 그리고 오픈소스 커뮤니티의 도움으로 학습 목적으로 개발되었습니다.

**사용된 오픈소스 라이브러리**:
- Flutter & Dart Team
- Riverpod (Remi Rousselet)
- Dio (cfug)
- GoRouter (Flutter Team)
- Encrypt (leocavalcante)

---

**⚠️ 다시 한번 강조합니다:**

이 프로젝트는 **학습 및 참고용**으로만 사용하세요. 배포하거나 악용하지 마세요. 모든 책임은 사용자 본인에게 있습니다.
