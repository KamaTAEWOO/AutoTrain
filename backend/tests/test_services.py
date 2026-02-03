"""
Backend 서비스 계층 테스트

RetryService: exponential backoff 동작 테스트
KorailService: 모킹 기반 로그인/검색/예약 테스트

korail2 실제 호출은 하지 않으며, 모든 외부 의존성을 모킹한다.
"""

import sys
import os
import asyncio
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch, MagicMock, PropertyMock

import pytest

# backend 디렉토리를 import 경로에 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.retry_service import exponential_backoff, retry_with_backoff
from services.korail_service import (
    KorailService,
    KorailServiceError,
    LoginFailedError,
    AccountBlockedError,
    SessionExpiredError,
    NoTrainsError,
    KorailServerError,
    SoldOutError,
    ReservationNotFoundError,
)

# 한국 시간대
KST = timezone(timedelta(hours=9))


# ──────────────────────────────────────────────
# RetryService 테스트
# ──────────────────────────────────────────────


class TestExponentialBackoffDecorator:
    """exponential_backoff 데코레이터 테스트"""

    @pytest.mark.asyncio
    async def test_success_on_first_attempt(self):
        """첫 번째 시도에서 성공하면 즉시 결과를 반환한다."""
        call_count = 0

        @exponential_backoff(base_delay=0.01, max_retries=3)
        async def succeed():
            nonlocal call_count
            call_count += 1
            return "ok"

        result = await succeed()

        assert result == "ok"
        assert call_count == 1

    @pytest.mark.asyncio
    async def test_retries_on_failure(self):
        """실패 후 재시도하여 성공하면 결과를 반환한다."""
        call_count = 0

        @exponential_backoff(base_delay=0.01, max_retries=3)
        async def fail_then_succeed():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ConnectionError("연결 실패")
            return "success"

        result = await fail_then_succeed()

        assert result == "success"
        assert call_count == 3

    @pytest.mark.asyncio
    async def test_raises_after_max_retries(self):
        """최대 재시도 횟수 초과 시 마지막 예외를 발생시킨다."""
        call_count = 0

        @exponential_backoff(base_delay=0.01, max_retries=2)
        async def always_fail():
            nonlocal call_count
            call_count += 1
            raise ConnectionError("연결 실패")

        with pytest.raises(ConnectionError, match="연결 실패"):
            await always_fail()

        # max_retries=2이면 총 3번 시도 (초기 1회 + 재시도 2회)
        assert call_count == 3

    @pytest.mark.asyncio
    async def test_non_retryable_exception_raised_immediately(self):
        """재시도 불가능한 예외는 즉시 발생시킨다."""
        call_count = 0

        @exponential_backoff(
            base_delay=0.01,
            max_retries=3,
            retryable_exceptions=(ConnectionError,),
        )
        async def raise_value_error():
            nonlocal call_count
            call_count += 1
            raise ValueError("재시도 불가")

        with pytest.raises(ValueError, match="재시도 불가"):
            await raise_value_error()

        assert call_count == 1  # 재시도 없이 즉시 발생

    @pytest.mark.asyncio
    async def test_retryable_exception_is_retried(self):
        """retryable_exceptions에 포함된 예외만 재시도한다."""
        call_count = 0

        @exponential_backoff(
            base_delay=0.01,
            max_retries=3,
            retryable_exceptions=(ConnectionError,),
        )
        async def connection_then_succeed():
            nonlocal call_count
            call_count += 1
            if call_count < 2:
                raise ConnectionError("재시도 가능")
            return "ok"

        result = await connection_then_succeed()

        assert result == "ok"
        assert call_count == 2

    @pytest.mark.asyncio
    async def test_delay_increases_exponentially(self):
        """대기 시간이 지수적으로 증가하는지 확인한다."""
        import time

        timestamps = []

        @exponential_backoff(base_delay=0.05, max_delay=1.0, max_retries=3)
        async def track_time():
            timestamps.append(time.monotonic())
            if len(timestamps) < 4:
                raise ConnectionError("fail")
            return "done"

        result = await track_time()
        assert result == "done"
        assert len(timestamps) == 4

        # 간격이 점점 증가하는지 확인 (대략적)
        if len(timestamps) >= 3:
            gap1 = timestamps[1] - timestamps[0]
            gap2 = timestamps[2] - timestamps[1]
            # 두 번째 간격이 첫 번째보다 크거나 같아야 함
            assert gap2 >= gap1 * 0.8  # 스케줄링 지터 허용

    @pytest.mark.asyncio
    async def test_max_delay_cap(self):
        """대기 시간이 max_delay를 초과하지 않는다."""
        import time

        timestamps = []

        @exponential_backoff(base_delay=0.1, max_delay=0.15, max_retries=3)
        async def track_time():
            timestamps.append(time.monotonic())
            if len(timestamps) < 4:
                raise ConnectionError("fail")
            return "done"

        await track_time()

        # 세 번째 간격 (0.1 * 2^2 = 0.4)이 max_delay(0.15)로 제한되어야 함
        if len(timestamps) >= 4:
            gap3 = timestamps[3] - timestamps[2]
            assert gap3 < 0.3  # max_delay + 여유


class TestRetryWithBackoff:
    """retry_with_backoff 함수형 인터페이스 테스트"""

    @pytest.mark.asyncio
    async def test_success_on_first_attempt(self):
        """첫 번째 시도에서 성공한다."""
        func = AsyncMock(return_value="ok")

        result = await retry_with_backoff(func, base_delay=0.01, max_retries=3)

        assert result == "ok"
        assert func.call_count == 1

    @pytest.mark.asyncio
    async def test_retries_and_succeeds(self):
        """실패 후 재시도하여 성공한다."""
        call_count = 0

        async def flaky():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ConnectionError("fail")
            return "success"

        result = await retry_with_backoff(flaky, base_delay=0.01, max_retries=3)

        assert result == "success"
        assert call_count == 3

    @pytest.mark.asyncio
    async def test_raises_after_max_retries(self):
        """최대 재시도 초과 시 예외를 발생시킨다."""
        async def always_fail():
            raise TimeoutError("timeout")

        with pytest.raises(TimeoutError, match="timeout"):
            await retry_with_backoff(
                always_fail, base_delay=0.01, max_retries=2
            )

    @pytest.mark.asyncio
    async def test_passes_args_and_kwargs(self):
        """함수에 인자가 올바르게 전달된다."""
        async def add(a, b, c=0):
            return a + b + c

        result = await retry_with_backoff(
            add, 1, 2, c=3, base_delay=0.01, max_retries=1
        )

        assert result == 6


# ──────────────────────────────────────────────
# KorailService 테스트
# ──────────────────────────────────────────────


class TestKorailServiceErrors:
    """KorailServiceError 계층 구조 테스트"""

    def test_login_failed_error(self):
        """LoginFailedError의 기본 속성을 확인한다."""
        error = LoginFailedError()
        assert error.error == "LOGIN_FAILED"
        assert error.code == "AUTH_001"
        assert "비밀번호" in error.detail

    def test_login_failed_error_custom_detail(self):
        """LoginFailedError에 커스텀 detail을 설정할 수 있다."""
        error = LoginFailedError("커스텀 메시지")
        assert error.detail == "커스텀 메시지"

    def test_account_blocked_error(self):
        """AccountBlockedError의 기본 속성을 확인한다."""
        error = AccountBlockedError()
        assert error.error == "ACCOUNT_BLOCKED"
        assert error.code == "AUTH_002"

    def test_session_expired_error(self):
        """SessionExpiredError의 기본 속성을 확인한다."""
        error = SessionExpiredError()
        assert error.error == "SESSION_EXPIRED"
        assert error.code == "AUTH_003"

    def test_no_trains_error(self):
        """NoTrainsError의 기본 속성을 확인한다."""
        error = NoTrainsError()
        assert error.error == "NO_TRAINS"
        assert error.code == "SEARCH_002"

    def test_korail_server_error(self):
        """KorailServerError의 기본 속성을 확인한다."""
        error = KorailServerError()
        assert error.error == "KORAIL_SERVER_ERROR"
        assert error.code == "SEARCH_003"

    def test_sold_out_error(self):
        """SoldOutError의 기본 속성을 확인한다."""
        error = SoldOutError()
        assert error.error == "SOLD_OUT"
        assert error.code == "RESERVE_001"

    def test_reservation_not_found_error(self):
        """ReservationNotFoundError의 기본 속성을 확인한다."""
        error = ReservationNotFoundError()
        assert error.error == "NOT_FOUND"
        assert error.code == "RESERVE_003"

    def test_errors_inherit_from_korail_service_error(self):
        """모든 에러가 KorailServiceError를 상속한다."""
        errors = [
            LoginFailedError(),
            AccountBlockedError(),
            SessionExpiredError(),
            NoTrainsError(),
            KorailServerError(),
            SoldOutError(),
            ReservationNotFoundError(),
        ]
        for error in errors:
            assert isinstance(error, KorailServiceError)
            assert isinstance(error, Exception)

    def test_errors_inherit_from_exception(self):
        """모든 에러가 Exception을 상속한다."""
        error = KorailServiceError("TEST", "TEST_001", "테스트")
        assert isinstance(error, Exception)
        assert str(error) == "테스트"


class TestKorailServiceLogin:
    """KorailService 로그인 테스트"""

    @pytest.mark.asyncio
    async def test_login_success(self):
        """로그인 성공 시 세션 토큰을 반환한다."""
        service = KorailService()

        # korail2.Korail 모킹
        mock_korail_class = MagicMock()
        mock_korail_instance = MagicMock()
        mock_korail_class.return_value = mock_korail_instance

        with patch.dict("sys.modules", {"korail2": MagicMock(Korail=mock_korail_class)}):
            result = await service.login("test_id", "test_pw")

        assert "session_token" in result
        assert "expires_at" in result
        assert result["message"] == "로그인 성공"
        assert service.is_session_valid()

    @pytest.mark.asyncio
    async def test_login_failure_wrong_password(self):
        """잘못된 비밀번호로 로그인 시 LoginFailedError를 발생시킨다."""
        service = KorailService()

        mock_korail_class = MagicMock()
        mock_korail_class.side_effect = Exception("비밀번호가 일치하지 않습니다")

        with patch.dict("sys.modules", {"korail2": MagicMock(Korail=mock_korail_class)}):
            with pytest.raises(LoginFailedError):
                await service.login("test_id", "wrong_pw")

    @pytest.mark.asyncio
    async def test_login_failure_blocked_account(self):
        """차단된 계정으로 로그인 시 AccountBlockedError를 발생시킨다."""
        service = KorailService()

        mock_korail_class = MagicMock()
        mock_korail_class.side_effect = Exception("계정이 차단되었습니다")

        with patch.dict("sys.modules", {"korail2": MagicMock(Korail=mock_korail_class)}):
            with pytest.raises(AccountBlockedError):
                await service.login("test_id", "test_pw")

    @pytest.mark.asyncio
    async def test_login_korail_server_error(self):
        """코레일 서버 오류 시 KorailServerError를 발생시킨다."""
        service = KorailService()

        mock_korail_class = MagicMock()
        mock_korail_class.side_effect = Exception("서버 응답 없음")

        with patch.dict("sys.modules", {"korail2": MagicMock(Korail=mock_korail_class)}):
            with pytest.raises(KorailServerError):
                await service.login("test_id", "test_pw")


class TestKorailServiceSession:
    """KorailService 세션 관리 테스트"""

    def test_initial_session_is_invalid(self):
        """초기 상태에서 세션이 유효하지 않다."""
        service = KorailService()
        assert not service.is_session_valid()

    def test_session_valid_after_login(self):
        """로그인 후 세션이 유효하다."""
        service = KorailService()
        # 세션 정보를 직접 설정
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) + timedelta(minutes=30)

        assert service.is_session_valid()

    def test_session_invalid_after_expiry(self):
        """만료 시간이 지나면 세션이 유효하지 않다."""
        service = KorailService()
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) - timedelta(minutes=1)

        assert not service.is_session_valid()


class TestKorailServiceSearchTrains:
    """KorailService 열차 조회 테스트"""

    @pytest.mark.asyncio
    async def test_search_trains_session_expired(self):
        """세션이 없으면 SessionExpiredError를 발생시킨다."""
        service = KorailService()

        with pytest.raises(SessionExpiredError):
            await service.search_trains("서울", "부산", "20260210", "090000")

    @pytest.mark.asyncio
    async def test_search_trains_success(self):
        """유효한 세션에서 열차 조회가 성공한다."""
        service = KorailService()
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) + timedelta(minutes=30)

        # 모킹된 열차 객체 생성
        mock_train = MagicMock()
        mock_train.train_no = "KTX-101"
        mock_train.train_type_name = "KTX"
        mock_train.dep_station_name = "서울"
        mock_train.arr_station_name = "부산"
        mock_train.dep_time = "090000"
        mock_train.arr_time = "113000"
        mock_train.general_seat_available = "O"
        mock_train.special_seat_available = "0"

        mock_korail = MagicMock()
        mock_korail.search_train.return_value = [mock_train]
        service._korail = mock_korail

        trains = await service.search_trains("서울", "부산", "20260210", "090000")

        assert len(trains) == 1
        assert trains[0].train_no == "KTX-101"
        assert trains[0].dep_station == "서울"
        assert trains[0].arr_station == "부산"
        assert trains[0].general_seats is True
        assert trains[0].special_seats is False

    @pytest.mark.asyncio
    async def test_search_trains_no_results(self):
        """검색 결과가 없으면 NoTrainsError를 발생시킨다."""
        service = KorailService()
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) + timedelta(minutes=30)

        mock_korail = MagicMock()
        mock_korail.search_train.return_value = []
        service._korail = mock_korail

        with pytest.raises(NoTrainsError):
            await service.search_trains("서울", "부산", "20260210", "090000")

    @pytest.mark.asyncio
    async def test_search_trains_korail_not_initialized(self):
        """korail 객체가 초기화되지 않았으면 KorailServerError를 발생시킨다."""
        service = KorailService()
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) + timedelta(minutes=30)
        service._korail = None

        with pytest.raises(KorailServerError):
            await service.search_trains("서울", "부산", "20260210", "090000")


class TestKorailServiceReserve:
    """KorailService 예약 테스트"""

    @pytest.mark.asyncio
    async def test_reserve_session_expired(self):
        """세션이 없으면 SessionExpiredError를 발생시킨다."""
        service = KorailService()

        with pytest.raises(SessionExpiredError):
            await service.reserve("KTX-101", "general")

    @pytest.mark.asyncio
    async def test_reserve_korail_not_initialized(self):
        """korail 객체가 초기화되지 않았으면 KorailServerError를 발생시킨다."""
        service = KorailService()
        service._session_token = "test_token"
        service._expires_at = datetime.now(KST) + timedelta(minutes=30)
        service._korail = None

        with pytest.raises(KorailServerError):
            await service.reserve("KTX-101", "general")


class TestKorailServiceHelpers:
    """KorailService 헬퍼 메서드 테스트"""

    def test_format_time_hhmmss(self):
        """HHmmss 형식의 시간 문자열을 HH:mm으로 변환한다."""
        assert KorailService._format_time("090000") == "09:00"
        assert KorailService._format_time("143000") == "14:30"
        assert KorailService._format_time("235959") == "23:59"

    def test_format_time_already_formatted(self):
        """이미 HH:mm 형식이면 그대로 반환한다."""
        assert KorailService._format_time("09:00") == "09:00"
        assert KorailService._format_time("14:30") == "14:30"

    def test_format_time_short_string(self):
        """짧은 문자열은 그대로 반환한다."""
        assert KorailService._format_time("09") == "09"

    def test_has_seats_true_values(self):
        """좌석이 있는 경우 True를 반환한다."""
        assert KorailService._has_seats("O") is True
        assert KorailService._has_seats("1") is True
        assert KorailService._has_seats("있음") is True
        assert KorailService._has_seats(True) is True
        assert KorailService._has_seats(1) is True

    def test_has_seats_false_values(self):
        """좌석이 없는 경우 False를 반환한다."""
        assert KorailService._has_seats("0") is False
        assert KorailService._has_seats("매진") is False
        assert KorailService._has_seats("sold out") is False
        assert KorailService._has_seats("없음") is False
        assert KorailService._has_seats("false") is False
        assert KorailService._has_seats("") is False
        assert KorailService._has_seats(False) is False
        assert KorailService._has_seats(0) is False
