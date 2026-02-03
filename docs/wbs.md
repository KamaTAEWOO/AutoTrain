# KTX 자동 조회·예약 테스트 앱 - WBS (Work Breakdown Structure)

---

## Phase 1: 기본 조회 (OpenAPI + Flutter UI)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 | 설명 |
|---------|--------|------|--------|--------|------|
| P1-BE-001 | FastAPI 프로젝트 초기 설정 | /be-dev | - | S | FastAPI 앱, CORS, 프로젝트 구조, requirements.txt |
| P1-BE-002 | 로그인 API 구현 | /be-dev | P1-BE-001 | M | POST /api/auth/login, korail2 로그인, 세션 토큰 반환 |
| P1-BE-003 | 열차 조회 API 구현 | /be-dev | P1-BE-002 | M | GET /api/trains/search, korail2.search_train() 래핑 |
| P1-FE-001 | Flutter 프로젝트 구조 설정 | /fe-dev | - | S | core/data/presentation 3계층, 의존성 추가 |
| P1-FE-002 | 데이터 모델 정의 | /fe-dev | P1-FE-001 | S | Train, SearchCondition, Reservation, LogEntry 모델 |
| P1-FE-003 | API 클라이언트 설정 | /fe-dev | P1-FE-001 | S | dio 인스턴스, 인터셉터, 타임아웃 설정 |
| P1-FE-004 | 검색 화면 (SearchScreen) UI | /fe-dev | P1-FE-002 | M | 출발역/도착역/날짜/시간 폼, 자동예약 토글 |
| P1-FE-005 | 열차 목록 표시 | /fe-dev | P1-FE-004 | S | 조회 결과 ListView, 열차 카드 위젯 |

### 병렬 처리 가능
- **Track A**: P1-BE-001 → P1-BE-002 → P1-BE-003 (백엔드)
- **Track B**: P1-FE-001 → P1-FE-002 → P1-FE-003 → P1-FE-004 → P1-FE-005 (프론트엔드)
- **동기화**: Track A, B 독립 진행 가능 (FE는 Mock 데이터 사용)

---

## Phase 2: 자동화 (주기 조회 + 조건 감시)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 | 설명 |
|---------|--------|------|--------|--------|------|
| P2-FE-001 | Riverpod Provider 구조 설정 | /fe-dev | P1-FE-005 | M | searchProvider, monitorProvider, reservationProvider |
| P2-FE-002 | 모니터 화면 (MonitorScreen) UI | /fe-dev | P2-FE-001 | M | 상태 카드, 조회 횟수, 로그 스크롤 |
| P2-FE-003 | Timer 기반 자동 조회 로직 | /fe-dev | P2-FE-001 | M | Timer.periodic, WidgetsBindingObserver lifecycle 관리 |
| P2-FE-004 | 상태 전이 관리 | /fe-dev | P2-FE-003 | M | idle→searching→found→reserving→success/failure 상태 머신 |
| P2-FE-005 | BottomNavigationBar 네비게이션 | /fe-dev | P2-FE-002 | S | 3화면 탭 전환 (검색/모니터/결과) |

### 병렬 처리 가능
- P2-FE-002 (UI)와 P2-FE-003 (로직)은 P2-FE-001 완료 후 병렬 진행 가능

---

## Phase 3: 예약 테스트 (Backend + korail2)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 | 설명 |
|---------|--------|------|--------|--------|------|
| P3-BE-001 | 예약 API 구현 | /be-dev | P1-BE-003 | M | POST /api/reservation, korail2.reserve() 래핑 |
| P3-BE-002 | 세션 관리 서비스 | /be-dev | P1-BE-002 | M | 세션 캐싱, 자동 재로그인, 만료 감지 |
| P3-BE-003 | 재시도/백오프 서비스 | /be-dev | P3-BE-001 | M | exponential backoff 데코레이터 (5s→10s→20s→60s) |
| P3-FE-001 | 결과 화면 (ResultScreen) UI | /fe-dev | P2-FE-005 | M | 성공/실패 카드, 예약 상세, 로그 표시 |
| P3-FE-002 | FE-BE API 연동 | /fe-dev | P3-BE-001, P3-FE-001 | L | Mock → 실제 API 전환, 에러 핸들링 통합 |

### 병렬 처리 가능
- **Track A**: P3-BE-001 → P3-BE-002 → P3-BE-003 (백엔드)
- **Track B**: P3-FE-001 (프론트엔드, Mock 사용)
- **동기화**: P3-FE-002는 Track A, B 모두 완료 후

---

## Phase 4: 안정화 (로그, 예외 처리, 재시도)

| Task ID | 작업명 | 담당 | 의존성 | 복잡도 | 설명 |
|---------|--------|------|--------|--------|------|
| P4-BE-001 | Backend 로깅 강화 | /be-dev | P3-BE-003 | S | 요청/응답/에러 상세 로그, 파일 로깅 |
| P4-BE-002 | Backend 예외 처리 통합 | /be-dev | P3-BE-003 | M | 글로벌 에러 핸들러, 에러 코드 체계 |
| P4-FE-001 | Frontend 에러 핸들링 | /fe-dev | P3-FE-002 | M | 네트워크/API/비즈니스 에러 분류, 사용자 알림 |
| P4-FE-002 | 로그 뷰어 구현 | /fe-dev | P3-FE-002 | S | 로그 버퍼(500건), 시간순 표시, 필터링 |
| P4-TEST-001 | Flutter 위젯 테스트 | /tester | P4-FE-001 | M | SearchScreen, MonitorScreen, ResultScreen 테스트 |
| P4-TEST-002 | Backend API 테스트 | /tester | P4-BE-002 | M | pytest + FastAPI TestClient, 모킹 |
| P4-REVIEW-001 | 코드 리뷰 및 아키텍처 검토 | /reviewer | P4-TEST-001, P4-TEST-002 | M | 코드 품질, 보안, 아키텍처 일관성 |

### 병렬 처리 가능
- **Track A**: P4-BE-001 → P4-BE-002 (백엔드 안정화)
- **Track B**: P4-FE-001 → P4-FE-002 (프론트엔드 안정화)
- **Track C**: P4-TEST-001 + P4-TEST-002 (Track A, B 완료 후 병렬 테스트)
- **최종**: P4-REVIEW-001 (테스트 완료 후)

---

## 전체 의존성 그래프

```
Phase 1 (병렬)                Phase 2              Phase 3 (병렬)           Phase 4 (병렬)
┌─────────────────┐
│ P1-BE-001~003   │──────────────────────────→ P3-BE-001~003 ──→ P4-BE-001~002
│ (Backend 기본)   │                           (예약 Backend)     (BE 안정화)
└─────────────────┘                                                    │
                                                                       ▼
┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐    P4-TEST-001~002
│ P1-FE-001~005   │→│ P2-FE-001~005    │→│ P3-FE-001~002 │──→ (테스트)
│ (Frontend 기본)  │  │ (자동화)          │  │ (예약 FE+연동) │     │
└─────────────────┘  └──────────────────┘  └───────────────┘    P4-FE-001~002
                                                                (FE 안정화)
                                                                       │
                                                                       ▼
                                                                P4-REVIEW-001
                                                                (최종 리뷰)
```

---

## 요약 통계

| Phase | FE 작업 | BE 작업 | 테스트 | 리뷰 | 합계 |
|-------|---------|---------|--------|------|------|
| Phase 1 | 5 | 3 | - | - | 8 |
| Phase 2 | 5 | - | - | - | 5 |
| Phase 3 | 2 | 3 | - | - | 5 |
| Phase 4 | 2 | 2 | 2 | 1 | 7 |
| **합계** | **14** | **8** | **2** | **1** | **25** |

### 크리티컬 패스
P1-FE-001 → P1-FE-002 → P1-FE-004 → P2-FE-001 → P2-FE-003 → P2-FE-004 → P3-FE-001 → P3-FE-002 → P4-FE-001 → P4-TEST-001 → P4-REVIEW-001
