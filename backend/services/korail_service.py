"""
KorailService - korail2 라이브러리 래핑 서비스
코레일 비공식 API를 통한 로그인, 열차 조회, 예약 기능을 제공한다.
세션 캐싱 및 자동 재로그인 기능을 포함한다.
"""

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from models.schemas import TrainInfo, ReservationResponse, ReservationDetailResponse

logger = logging.getLogger(__name__)

# 한국 시간대 (KST = UTC+9)
KST = timezone(timedelta(hours=9))


class KorailServiceError(Exception):
    """KorailService 기본 예외"""

    def __init__(self, error: str, code: str, detail: str):
        self.error = error
        self.code = code
        self.detail = detail
        super().__init__(detail)


class LoginFailedError(KorailServiceError):
    """로그인 실패"""

    def __init__(self, detail: str = "아이디 또는 비밀번호가 올바르지 않습니다"):
        super().__init__(error="LOGIN_FAILED", code="AUTH_001", detail=detail)


class AccountBlockedError(KorailServiceError):
    """계정 차단"""

    def __init__(self, detail: str = "계정이 제한되었습니다"):
        super().__init__(error="ACCOUNT_BLOCKED", code="AUTH_002", detail=detail)


class SessionExpiredError(KorailServiceError):
    """세션 만료"""

    def __init__(self, detail: str = "세션이 만료되었습니다. 다시 로그인해주세요"):
        super().__init__(error="SESSION_EXPIRED", code="AUTH_003", detail=detail)


class NoTrainsError(KorailServiceError):
    """열차 없음"""

    def __init__(self, detail: str = "해당 조건의 열차가 없습니다"):
        super().__init__(error="NO_TRAINS", code="SEARCH_002", detail=detail)


class KorailServerError(KorailServiceError):
    """코레일 서버 오류"""

    def __init__(self, detail: str = "코레일 서버 연결 실패"):
        super().__init__(error="KORAIL_SERVER_ERROR", code="SEARCH_003", detail=detail)


class SoldOutError(KorailServiceError):
    """매진"""

    def __init__(self, detail: str = "매진되었습니다"):
        super().__init__(error="SOLD_OUT", code="RESERVE_001", detail=detail)


class ReservationNotFoundError(KorailServiceError):
    """예약 없음"""

    def __init__(self, detail: str = "예약을 찾을 수 없습니다"):
        super().__init__(error="NOT_FOUND", code="RESERVE_003", detail=detail)


class CancellationFailedError(KorailServiceError):
    """예약 취소 실패"""

    def __init__(self, detail: str = "예약 취소에 실패했습니다"):
        super().__init__(error="CANCELLATION_FAILED", code="RESERVE_004", detail=detail)


class KorailService:
    """
    korail2 라이브러리를 래핑하는 서비스 클래스.

    기능:
    - 코레일 로그인 및 세션 관리
    - 열차 조회
    - 예약 생성 및 조회
    - 세션 캐싱 및 자동 재로그인
    """

    # 세션 유효 시간 (기본 30분)
    SESSION_DURATION_MINUTES = 30

    def __init__(self):
        self._korail = None  # korail2.Korail 인스턴스 (lazy init)
        self._session_token: Optional[str] = None
        self._expires_at: Optional[datetime] = None
        self._korail_id: Optional[str] = None
        self._korail_pw: Optional[str] = None
        self._reservations: dict[str, ReservationDetailResponse] = {}

        logger.info("[KorailService] 서비스 초기화 완료")

    def is_session_valid(self) -> bool:
        """세션이 유효한지 확인한다."""
        if self._session_token is None or self._expires_at is None:
            return False
        return datetime.now(KST) < self._expires_at

    async def _ensure_session(self) -> None:
        """
        세션 유효성을 검사하고, 만료된 경우 자동 재로그인을 시도한다.

        Raises:
            SessionExpiredError: 세션이 만료되고 재로그인도 실패한 경우
        """
        if self.is_session_valid():
            return

        # 저장된 자격 증명이 있으면 자동 재로그인 시도
        if self._korail_id and self._korail_pw:
            logger.info("[KorailService] 세션 만료 감지 - 자동 재로그인 시도")
            try:
                await self.login(self._korail_id, self._korail_pw)
                logger.info("[KorailService] 자동 재로그인 성공")
                return
            except Exception as e:
                logger.error("[KorailService] 자동 재로그인 실패: %s", str(e))

        raise SessionExpiredError()

    async def login(self, korail_id: str, korail_pw: str) -> dict:
        """
        코레일 계정으로 로그인한다.

        Args:
            korail_id: 코레일 멤버십 번호 또는 이메일
            korail_pw: 코레일 비밀번호

        Returns:
            dict: session_token, expires_at, message

        Raises:
            LoginFailedError: 아이디/비밀번호 오류
            AccountBlockedError: 계정 차단
            KorailServerError: 코레일 서버 통신 오류
        """
        logger.info("[KorailService] 로그인 시도 - ID: %s", korail_id[:3] + "***")

        try:
            from korail2 import Korail

            self._korail = Korail(korail_id, korail_pw, auto_login=True)

            # korail2의 login()은 실패 시 예외를 던지지 않고
            # False를 반환하며 self.logined = False로 설정한다.
            # 따라서 반드시 logined 상태를 확인해야 한다.
            if not getattr(self._korail, "logined", False):
                self._korail = None
                raise LoginFailedError()

            # 로그인 성공 - 세션 정보 저장
            self._korail_id = korail_id
            self._korail_pw = korail_pw
            self._session_token = uuid.uuid4().hex
            self._expires_at = datetime.now(KST) + timedelta(
                minutes=self.SESSION_DURATION_MINUTES
            )

            member_name = getattr(self._korail, "name", "") or ""
            logger.info("[KorailService] 로그인 성공 - %s", member_name)

            return {
                "session_token": self._session_token,
                "expires_at": self._expires_at.isoformat(),
                "name": member_name,
                "message": "로그인 성공",
            }

        except (LoginFailedError, AccountBlockedError, KorailServerError):
            raise

        except ImportError:
            logger.error("[KorailService] korail2 모듈을 찾을 수 없습니다")
            raise KorailServerError(detail="korail2 모듈을 사용할 수 없습니다")

        except Exception as e:
            error_msg = str(e).lower()
            logger.error("[KorailService] 로그인 실패: %s", str(e))

            if "비밀번호" in error_msg or "password" in error_msg or "login" in error_msg:
                raise LoginFailedError()
            elif "차단" in error_msg or "block" in error_msg or "제한" in error_msg:
                raise AccountBlockedError()
            else:
                raise KorailServerError(
                    detail=f"코레일 서버 연결 실패: {str(e)}"
                )

    async def search_trains(
        self, dep: str, arr: str, date: str, time: str
    ) -> list[TrainInfo]:
        """
        출발역/도착역/날짜/시간 조건으로 KTX 열차 목록을 조회한다.

        Args:
            dep: 출발역 이름 (한글)
            arr: 도착역 이름 (한글)
            date: 출발 날짜 (YYYYMMDD)
            time: 출발 시간 (HHmmss)

        Returns:
            list[TrainInfo]: 열차 정보 목록

        Raises:
            SessionExpiredError: 세션 만료
            NoTrainsError: 해당 조건의 열차 없음
            KorailServerError: 코레일 서버 오류
        """
        await self._ensure_session()

        logger.info(
            "[KorailService] 열차 조회 - %s -> %s, %s %s",
            dep, arr, date, time,
        )

        try:
            if self._korail is None:
                raise KorailServerError(detail="코레일 세션이 초기화되지 않았습니다")

            # korail2의 search_train 호출
            trains = self._korail.search_train(dep, arr, date, time)

            if not trains:
                raise NoTrainsError()

            train_list: list[TrainInfo] = []
            for train in trains:
                try:
                    train_info = TrainInfo(
                        train_no=getattr(train, "train_no", "N/A"),
                        train_type=getattr(train, "train_type_name", "KTX"),
                        dep_station=getattr(train, "dep_station_name", dep),
                        arr_station=getattr(train, "arr_station_name", arr),
                        dep_time=self._format_time(
                            getattr(train, "dep_time", "000000")
                        ),
                        arr_time=self._format_time(
                            getattr(train, "arr_time", "000000")
                        ),
                        general_seats=self._has_seats(
                            getattr(train, "general_seat_available", "0")
                        ),
                        special_seats=self._has_seats(
                            getattr(train, "special_seat_available", "0")
                        ),
                    )
                    train_list.append(train_info)
                except Exception as parse_err:
                    logger.warning(
                        "[KorailService] 열차 정보 파싱 오류 (건너뜀): %s",
                        str(parse_err),
                    )
                    continue

            logger.info(
                "[KorailService] 조회 완료 - %d건 (좌석 있음: %d건)",
                len(train_list),
                sum(1 for t in train_list if t.general_seats or t.special_seats),
            )

            return train_list

        except (NoTrainsError, SessionExpiredError, KorailServerError):
            raise

        except Exception as e:
            error_msg = str(e).lower()
            logger.error("[KorailService] 열차 조회 실패: %s", str(e))

            if "결과가 없습니다" in str(e) or "no result" in error_msg:
                raise NoTrainsError()
            elif "session" in error_msg or "만료" in error_msg:
                self._session_token = None
                self._expires_at = None
                raise SessionExpiredError()
            else:
                raise KorailServerError(
                    detail=f"코레일 서버 연결 실패: {str(e)}"
                )

    async def reserve(
        self,
        train_no: str,
        seat_type: str,
        dep: str,
        arr: str,
        date: str,
        time: str = "000000",
    ) -> ReservationResponse:
        """
        선택한 열차에 대해 예약을 시도한다.

        Args:
            train_no: 예약할 열차 번호
            seat_type: 좌석 유형 ("general" 또는 "special")
            dep: 출발역
            arr: 도착역
            date: 출발 날짜 (YYYYMMDD)
            time: 출발 시간 (HHmmss)

        Returns:
            ReservationResponse: 예약 결과

        Raises:
            SessionExpiredError: 세션 만료
            SoldOutError: 매진
            KorailServerError: 코레일 서버 오류
        """
        await self._ensure_session()

        logger.info(
            "[KorailService] 예약 시도 - 열차: %s, 좌석: %s, %s->%s %s %s",
            train_no, seat_type, dep, arr, date, time,
        )

        try:
            if self._korail is None:
                raise KorailServerError(detail="코레일 세션이 초기화되지 않았습니다")

            # 프론트에서 전달받은 검색 조건으로 열차를 재검색하여
            # korail2 Train 객체를 얻는다 (reserve에 필요)
            trains = self._korail.search_train_allday(
                dep, arr, date, time,
            )

            # 검색된 열차 정보 수집 (디버깅용)
            found_info = []
            target_train = None
            normalized_req = train_no.strip().lstrip("0")

            # 1차: train_no 매칭 (정규화 비교)
            for train in trains:
                raw_no = getattr(train, "train_no", "")
                raw_dep = getattr(train, "dep_time", "")
                found_info.append(f"{raw_no}({raw_dep})")
                normalized = raw_no.strip().lstrip("0")
                if normalized == normalized_req:
                    target_train = train
                    break

            # 2차: train_no 매칭 실패 시 dep_time으로 폴백 매칭
            # TAGO API와 korail2의 열차번호 포맷이 다를 수 있으므로
            # 출발시간이 일치하는 열차를 찾는다
            if target_train is None and time != "000000":
                # time을 HHmm으로 정규화 (HH:MM → HHmm, HHmmss → HHmm)
                clean_time = time.replace(":", "")
                req_hhmm = clean_time[:4]  # HHmm
                for train in trains:
                    raw_dep = getattr(train, "dep_time", "")
                    # korail2의 dep_time도 정규화
                    clean_dep = raw_dep.replace(":", "")
                    dep_hhmm = clean_dep[:4] if len(clean_dep) >= 4 else ""
                    if dep_hhmm == req_hhmm:
                        target_train = train
                        logger.info(
                            "[KorailService] train_no 매칭 실패, dep_time 폴백 매칭 성공 - "
                            "요청 train_no: '%s', 매칭된 korail2 train_no: '%s', dep_time: %s",
                            train_no, getattr(train, "train_no", ""), raw_dep,
                        )
                        break

            if target_train is None:
                clean_time = time.replace(":", "")
                req_hhmm = clean_time[:4]
                logger.warning(
                    "[KorailService] 열차 매칭 실패 - "
                    "요청 train_no: '%s' (normalized: '%s'), "
                    "요청 time: '%s' (HHmm: '%s'), "
                    "검색된 열차: [%s]",
                    train_no, normalized_req, time, req_hhmm,
                    ", ".join(found_info) if found_info else "없음",
                )
                raise NoTrainsError(
                    detail=f"열차 {train_no}을 찾을 수 없습니다. "
                           f"검색된 열차: {', '.join(found_info) if found_info else '없음'}"
                )

            # 좌석 유형에 따라 예약 시도
            if seat_type == "special":
                reservation = self._korail.reserve(target_train, option="SPECIAL_FIRST")
            else:
                reservation = self._korail.reserve(target_train)

            # 예약 성공
            now = datetime.now(KST)
            reservation_id = getattr(
                reservation,
                "rsv_id",
                f"R{now.strftime('%Y%m%d')}{uuid.uuid4().hex[:3].upper()}"
            )

            train_info = TrainInfo(
                train_no=train_no,
                train_type=getattr(target_train, "train_type_name", "KTX"),
                dep_station=getattr(target_train, "dep_station_name", ""),
                arr_station=getattr(target_train, "arr_station_name", ""),
                dep_time=self._format_time(
                    getattr(target_train, "dep_time", "000000")
                ),
                arr_time=self._format_time(
                    getattr(target_train, "arr_time", "000000")
                ),
                general_seats=seat_type == "general",
                special_seats=seat_type == "special",
            )

            response = ReservationResponse(
                reservation_id=reservation_id,
                status="success",
                train=train_info,
                message="예약 성공. 10분 내 결제 필요",
                reserved_at=now.isoformat(),
            )

            # 예약 상세 정보 저장 (조회용)
            payment_deadline = now + timedelta(minutes=10)
            self._reservations[reservation_id] = ReservationDetailResponse(
                reservation_id=reservation_id,
                status="success",
                train=train_info,
                reserved_at=now.isoformat(),
                payment_deadline=payment_deadline.isoformat(),
            )

            logger.info(
                "[KorailService] 예약 성공 - 예약번호: %s", reservation_id
            )

            return response

        except (
            NoTrainsError, SessionExpiredError,
            SoldOutError, KorailServerError,
        ):
            raise

        except Exception as e:
            error_msg = str(e).lower()
            logger.error("[KorailService] 예약 실패: %s", str(e))

            if "매진" in str(e) or "sold out" in error_msg or "no seat" in error_msg:
                raise SoldOutError()
            elif "session" in error_msg or "만료" in error_msg:
                self._session_token = None
                self._expires_at = None
                raise SessionExpiredError(detail="세션이 만료되었습니다")
            else:
                raise KorailServerError(
                    detail=f"코레일 서버와 통신할 수 없습니다: {str(e)}"
                )

    async def list_reservations(self) -> list[ReservationDetailResponse]:
        """
        현재 계정의 모든 예약 목록을 조회한다.

        Returns:
            list[ReservationDetailResponse]: 예약 목록

        Raises:
            SessionExpiredError: 세션 만료
            KorailServerError: 코레일 서버 오류
        """
        await self._ensure_session()

        logger.info("[KorailService] 예약 목록 조회")

        try:
            if self._korail is None:
                raise KorailServerError(detail="코레일 세션이 초기화되지 않았습니다")

            reservations = self._korail.reservations()

            result: list[ReservationDetailResponse] = []
            for rsv in reservations:
                try:
                    rsv_id = getattr(rsv, "rsv_id", "")
                    train_info = TrainInfo(
                        train_no=getattr(rsv, "train_no", "N/A"),
                        train_type=getattr(rsv, "train_type_name", "KTX"),
                        dep_station=getattr(rsv, "dep_station_name", ""),
                        arr_station=getattr(rsv, "arr_station_name", ""),
                        dep_time=self._format_time(
                            getattr(rsv, "dep_time", "000000")
                        ),
                        arr_time=self._format_time(
                            getattr(rsv, "arr_time", "000000")
                        ),
                        general_seats=True,
                        special_seats=False,
                    )

                    detail = ReservationDetailResponse(
                        reservation_id=rsv_id,
                        status="success",
                        train=train_info,
                        reserved_at=getattr(rsv, "rsv_date", ""),
                        payment_deadline=getattr(rsv, "pay_limit_date", None),
                    )
                    result.append(detail)
                except Exception as parse_err:
                    logger.warning(
                        "[KorailService] 예약 정보 파싱 오류 (건너뜀): %s",
                        str(parse_err),
                    )
                    continue

            logger.info("[KorailService] 예약 목록 조회 완료 - %d건", len(result))
            return result

        except (SessionExpiredError, KorailServerError):
            raise

        except Exception as e:
            error_msg = str(e).lower()
            logger.error("[KorailService] 예약 목록 조회 실패: %s", str(e))

            if "session" in error_msg or "만료" in error_msg:
                self._session_token = None
                self._expires_at = None
                raise SessionExpiredError()
            elif "결과가 없습니다" in str(e) or "no result" in error_msg:
                return []
            else:
                raise KorailServerError(
                    detail=f"코레일 서버 연결 실패: {str(e)}"
                )

    async def get_reservation(self, reservation_id: str) -> ReservationDetailResponse:
        """
        예약 번호로 예약 상세 정보를 조회한다.

        Args:
            reservation_id: 예약 번호

        Returns:
            ReservationDetailResponse: 예약 상세 정보

        Raises:
            SessionExpiredError: 세션 만료
            ReservationNotFoundError: 예약 없음
        """
        await self._ensure_session()

        logger.info("[KorailService] 예약 조회 - ID: %s", reservation_id)

        # 메모리에 저장된 예약 정보 확인
        if reservation_id in self._reservations:
            logger.info("[KorailService] 예약 조회 성공 (캐시)")
            return self._reservations[reservation_id]

        # korail2를 통한 예약 조회 시도
        try:
            if self._korail is None:
                raise KorailServerError(detail="코레일 세션이 초기화되지 않았습니다")

            reservations = self._korail.reservations()

            for rsv in reservations:
                rsv_id = getattr(rsv, "rsv_id", "")
                if rsv_id == reservation_id:
                    train_info = TrainInfo(
                        train_no=getattr(rsv, "train_no", "N/A"),
                        train_type=getattr(rsv, "train_type_name", "KTX"),
                        dep_station=getattr(rsv, "dep_station_name", ""),
                        arr_station=getattr(rsv, "arr_station_name", ""),
                        dep_time=self._format_time(
                            getattr(rsv, "dep_time", "000000")
                        ),
                        arr_time=self._format_time(
                            getattr(rsv, "arr_time", "000000")
                        ),
                        general_seats=True,
                        special_seats=False,
                    )

                    detail = ReservationDetailResponse(
                        reservation_id=rsv_id,
                        status="success",
                        train=train_info,
                        reserved_at=getattr(rsv, "rsv_date", ""),
                        payment_deadline=getattr(rsv, "pay_limit_date", None),
                    )

                    logger.info("[KorailService] 예약 조회 성공 (korail2)")
                    return detail

            raise ReservationNotFoundError()

        except (ReservationNotFoundError, SessionExpiredError, KorailServerError):
            raise

        except Exception as e:
            logger.error("[KorailService] 예약 조회 실패: %s", str(e))
            raise ReservationNotFoundError()

    async def cancel_reservation(self, reservation_id: str) -> dict:
        """
        예약을 취소한다.

        Args:
            reservation_id: 예약 번호

        Returns:
            dict: 취소 결과 (reservation_id, status, message, cancelled_at)

        Raises:
            SessionExpiredError: 세션 만료
            ReservationNotFoundError: 예약 없음
            CancellationFailedError: 취소 실패
        """
        await self._ensure_session()

        logger.info("[KorailService] 예약 취소 시도 - ID: %s", reservation_id)

        try:
            if self._korail is None:
                raise KorailServerError(detail="코레일 세션이 초기화되지 않았습니다")

            # korail2를 통해 예약 목록 조회
            reservations = self._korail.reservations()

            target_rsv = None
            for rsv in reservations:
                if getattr(rsv, "rsv_id", "") == reservation_id:
                    target_rsv = rsv
                    break

            if target_rsv is None:
                raise ReservationNotFoundError()

            # korail2의 cancel 메서드 호출
            self._korail.cancel(target_rsv)

            now = datetime.now(KST)

            # 메모리 캐시에서도 제거
            self._reservations.pop(reservation_id, None)

            logger.info("[KorailService] 예약 취소 성공 - ID: %s", reservation_id)

            return {
                "reservation_id": reservation_id,
                "status": "cancelled",
                "message": "예약이 취소되었습니다",
                "cancelled_at": now.isoformat(),
            }

        except (ReservationNotFoundError, SessionExpiredError, KorailServerError):
            raise

        except CancellationFailedError:
            raise

        except Exception as e:
            error_msg = str(e).lower()
            logger.error("[KorailService] 예약 취소 실패: %s", str(e))

            if "session" in error_msg or "만료" in error_msg:
                self._session_token = None
                self._expires_at = None
                raise SessionExpiredError()
            else:
                raise CancellationFailedError(
                    detail=f"예약 취소에 실패했습니다: {str(e)}"
                )

    @staticmethod
    def _format_time(time_str: str) -> str:
        """
        시간 문자열을 HH:mm 형식으로 변환한다.

        Args:
            time_str: 원본 시간 문자열 (HHmmss 또는 HH:mm:ss 등)

        Returns:
            str: HH:mm 형식의 시간 문자열
        """
        # 이미 HH:mm 형식인 경우
        if len(time_str) == 5 and ":" in time_str:
            return time_str

        # HHmmss 형식 (6자리)
        clean = time_str.replace(":", "").replace(" ", "")
        if len(clean) >= 4:
            return f"{clean[:2]}:{clean[2:4]}"

        return time_str

    @staticmethod
    def _has_seats(seat_value: str) -> bool:
        """
        좌석 가용 여부를 판단한다.

        Args:
            seat_value: korail2의 좌석 가용 정보 값

        Returns:
            bool: 좌석이 있으면 True
        """
        if isinstance(seat_value, bool):
            return seat_value
        if isinstance(seat_value, int):
            return seat_value > 0

        val = str(seat_value).strip().lower()
        # "0", "매진", "sold out" 등은 좌석 없음
        if val in ("0", "매진", "sold out", "없음", "false", ""):
            return False
        return True
