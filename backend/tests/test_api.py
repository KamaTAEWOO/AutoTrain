"""
Backend API 엔드포인트 테스트

FastAPI TestClient를 사용하여 각 API 엔드포인트의 요청/응답을 검증한다.
korail2 실제 호출은 하지 않으며, KorailService를 모킹하여 테스트한다.
"""

import sys
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch, MagicMock

import pytest

# backend 디렉토리를 import 경로에 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient

from main import app
from api.deps import get_korail_service, verify_session
from services.korail_service import (
    KorailService,
    LoginFailedError,
    SessionExpiredError,
    SoldOutError,
    KorailServerError,
    NoTrainsError,
)
from models.schemas import TrainInfo, ReservationResponse

# 한국 시간대
KST = timezone(timedelta(hours=9))


# ──────────────────────────────────────────────
# Fixtures
# ──────────────────────────────────────────────


@pytest.fixture
def mock_service():
    """모킹된 KorailService 인스턴스를 반환한다."""
    service = MagicMock(spec=KorailService)
    service.is_session_valid.return_value = True
    return service


@pytest.fixture
def client(mock_service):
    """
    KorailService를 모킹한 TestClient를 반환한다.
    verify_session 의존성도 모킹하여 세션 검증을 건너뛴다.
    """

    async def override_get_korail_service():
        return mock_service

    async def override_verify_session():
        return mock_service

    app.dependency_overrides[get_korail_service] = override_get_korail_service
    app.dependency_overrides[verify_session] = override_verify_session

    yield TestClient(app)

    # 테스트 후 의존성 오버라이드 정리
    app.dependency_overrides.clear()


@pytest.fixture
def sample_train_info():
    """테스트용 TrainInfo 객체를 반환한다."""
    return TrainInfo(
        train_no="KTX-101",
        train_type="KTX",
        dep_station="서울",
        arr_station="부산",
        dep_time="09:00",
        arr_time="11:30",
        general_seats=True,
        special_seats=False,
    )


# ──────────────────────────────────────────────
# 헬스체크 테스트
# ──────────────────────────────────────────────


class TestHealthCheck:
    """헬스체크 엔드포인트 테스트"""

    def test_health_check_returns_ok(self, client):
        """GET /health 가 200 OK를 반환한다."""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "service" in data


# ──────────────────────────────────────────────
# POST /api/auth/login 테스트
# ──────────────────────────────────────────────


class TestAuthLogin:
    """인증 로그인 API 테스트"""

    def test_login_success(self, client, mock_service):
        """로그인 성공 시 session_token을 포함한 응답을 반환한다."""
        mock_service.login = AsyncMock(
            return_value={
                "session_token": "test_token_abc123",
                "expires_at": "2026-02-02T23:59:59+09:00",
                "message": "로그인 성공",
            }
        )

        response = client.post(
            "/api/auth/login",
            json={"korail_id": "test_user", "korail_pw": "test_pass"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["session_token"] == "test_token_abc123"
        assert data["message"] == "로그인 성공"
        assert "expires_at" in data

    def test_login_failure_invalid_credentials(self, client, mock_service):
        """잘못된 자격 증명으로 로그인 시 401을 반환한다."""
        mock_service.login = AsyncMock(
            side_effect=LoginFailedError("아이디 또는 비밀번호가 올바르지 않습니다")
        )

        response = client.post(
            "/api/auth/login",
            json={"korail_id": "wrong_user", "korail_pw": "wrong_pass"},
        )

        assert response.status_code == 401
        data = response.json()
        detail = data["detail"]
        assert detail["error"] == "LOGIN_FAILED"
        assert detail["code"] == "AUTH_001"

    def test_login_korail_server_error(self, client, mock_service):
        """코레일 서버 오류 시 503을 반환한다."""
        mock_service.login = AsyncMock(
            side_effect=KorailServerError("코레일 서버 연결 실패")
        )

        response = client.post(
            "/api/auth/login",
            json={"korail_id": "test_user", "korail_pw": "test_pass"},
        )

        assert response.status_code == 503
        data = response.json()
        detail = data["detail"]
        assert detail["error"] == "KORAIL_SERVER_ERROR"

    def test_login_missing_fields(self, client):
        """필수 필드 누락 시 422를 반환한다."""
        response = client.post(
            "/api/auth/login",
            json={"korail_id": "test_user"},
        )

        assert response.status_code == 422

    def test_login_empty_body(self, client):
        """빈 요청 본문 시 422를 반환한다."""
        response = client.post("/api/auth/login", json={})

        assert response.status_code == 422

    def test_login_error_response_format(self, client, mock_service):
        """에러 응답이 표준 포맷(error, code, detail)을 따른다."""
        mock_service.login = AsyncMock(
            side_effect=LoginFailedError()
        )

        response = client.post(
            "/api/auth/login",
            json={"korail_id": "test", "korail_pw": "test"},
        )

        data = response.json()
        detail = data["detail"]
        assert "error" in detail
        assert "code" in detail
        assert "detail" in detail


# ──────────────────────────────────────────────
# GET /api/trains/search 테스트
# ──────────────────────────────────────────────


class TestTrainSearch:
    """열차 조회 API 테스트"""

    def _future_date(self) -> str:
        """테스트용 미래 날짜 문자열을 반환한다 (YYYYMMDD)."""
        future = datetime.now(KST) + timedelta(days=7)
        return future.strftime("%Y%m%d")

    def test_search_success(self, client, mock_service, sample_train_info):
        """유효한 파라미터로 열차 조회 시 200과 열차 목록을 반환한다."""
        mock_service.search_trains = AsyncMock(
            return_value=[sample_train_info]
        )

        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "부산",
                "date": self._future_date(),
                "time": "090000",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "trains" in data
        assert len(data["trains"]) == 1
        assert data["trains"][0]["train_no"] == "KTX-101"
        assert "searched_at" in data

    def test_search_missing_dep(self, client):
        """출발역 누락 시 422를 반환한다 (Query 필수 파라미터)."""
        response = client.get(
            "/api/trains/search",
            params={
                "arr": "부산",
                "date": self._future_date(),
                "time": "090000",
            },
        )

        assert response.status_code == 422

    def test_search_same_stations(self, client):
        """출발역과 도착역이 같으면 400을 반환한다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "서울",
                "date": self._future_date(),
                "time": "090000",
            },
        )

        assert response.status_code == 400
        data = response.json()
        detail = data["detail"]
        assert detail["code"] == "SEARCH_001"
        assert "같을 수 없습니다" in detail["detail"]

    def test_search_invalid_station(self, client):
        """유효하지 않은 역명이면 400을 반환한다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "없는역",
                "arr": "부산",
                "date": self._future_date(),
                "time": "090000",
            },
        )

        assert response.status_code == 400
        data = response.json()
        detail = data["detail"]
        assert "유효하지 않은 역명" in detail["detail"]

    def test_search_invalid_date_format(self, client):
        """날짜 형식이 올바르지 않으면 400을 반환한다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "부산",
                "date": "2026-02-05",  # YYYYMMDD가 아님
                "time": "090000",
            },
        )

        assert response.status_code == 400

    def test_search_past_date(self, client):
        """과거 날짜를 조회하면 400을 반환한다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "부산",
                "date": "20200101",
                "time": "090000",
            },
        )

        assert response.status_code == 400
        data = response.json()
        detail = data["detail"]
        assert "과거 날짜" in detail["detail"]

    def test_search_invalid_time_format(self, client):
        """시간 형식이 올바르지 않으면 400을 반환한다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "부산",
                "date": self._future_date(),
                "time": "25:00:00",  # HHmmss가 아님
            },
        )

        assert response.status_code == 400

    def test_search_error_response_format(self, client):
        """에러 응답이 표준 포맷(error, code, detail)을 따른다."""
        response = client.get(
            "/api/trains/search",
            params={
                "dep": "서울",
                "arr": "서울",
                "date": self._future_date(),
                "time": "090000",
            },
        )

        data = response.json()
        detail = data["detail"]
        assert "error" in detail
        assert "code" in detail
        assert "detail" in detail


# ──────────────────────────────────────────────
# POST /api/reservation 테스트
# ──────────────────────────────────────────────


class TestReservation:
    """예약 API 테스트"""

    def test_reserve_success(self, client, mock_service, sample_train_info):
        """유효한 요청으로 예약 시 200과 예약 결과를 반환한다."""
        now = datetime.now(KST)
        mock_service.reserve = AsyncMock(
            return_value=ReservationResponse(
                reservation_id="R20260202ABC",
                status="success",
                train=sample_train_info,
                message="예약 성공. 10분 내 결제 필요",
                reserved_at=now.isoformat(),
            )
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "general"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["reservation_id"] == "R20260202ABC"
        assert data["status"] == "success"
        assert data["train"]["train_no"] == "KTX-101"
        assert "message" in data

    def test_reserve_sold_out(self, client, mock_service):
        """매진 시 409를 반환한다."""
        mock_service.reserve = AsyncMock(
            side_effect=SoldOutError("매진되었습니다")
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "general"},
        )

        assert response.status_code == 409
        data = response.json()
        detail = data["detail"]
        assert detail["error"] == "SOLD_OUT"
        assert detail["code"] == "RESERVE_001"

    def test_reserve_session_expired(self, client, mock_service):
        """세션 만료 시 401을 반환한다."""
        mock_service.reserve = AsyncMock(
            side_effect=SessionExpiredError("세션이 만료되었습니다")
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "general"},
        )

        assert response.status_code == 401
        data = response.json()
        detail = data["detail"]
        assert detail["error"] == "SESSION_EXPIRED"

    def test_reserve_korail_server_error(self, client, mock_service):
        """코레일 서버 오류 시 503을 반환한다."""
        mock_service.reserve = AsyncMock(
            side_effect=KorailServerError("코레일 서버와 통신할 수 없습니다")
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "general"},
        )

        assert response.status_code == 503

    def test_reserve_invalid_seat_type(self, client):
        """유효하지 않은 좌석 유형이면 422를 반환한다."""
        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "vip"},
        )

        assert response.status_code == 422

    def test_reserve_missing_train_no(self, client):
        """열차 번호 누락 시 422를 반환한다."""
        response = client.post(
            "/api/reservation",
            json={"seat_type": "general"},
        )

        assert response.status_code == 422

    def test_reserve_default_seat_type(self, client, mock_service, sample_train_info):
        """seat_type을 생략하면 기본값 general로 처리한다."""
        now = datetime.now(KST)
        mock_service.reserve = AsyncMock(
            return_value=ReservationResponse(
                reservation_id="R20260202DEF",
                status="success",
                train=sample_train_info,
                message="예약 성공",
                reserved_at=now.isoformat(),
            )
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101"},
        )

        assert response.status_code == 200

    def test_reserve_error_response_format(self, client, mock_service):
        """에러 응답이 표준 포맷(error, code, detail)을 따른다."""
        mock_service.reserve = AsyncMock(
            side_effect=SoldOutError()
        )

        response = client.post(
            "/api/reservation",
            json={"train_no": "KTX-101", "seat_type": "general"},
        )

        data = response.json()
        detail = data["detail"]
        assert "error" in detail
        assert "code" in detail
        assert "detail" in detail
