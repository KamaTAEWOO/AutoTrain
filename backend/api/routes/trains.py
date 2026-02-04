"""
열차 조회 API 라우트
GET /api/trains/search - korail2를 통한 열차 조회 (로그인 필요)
                         미로그인 시 TAGO 공공데이터 폴백
"""

import logging
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Query

from api.deps import get_korail_service, get_tago_service
from models.schemas import TrainSearchResponse, ErrorResponse
from services.korail_service import (
    KorailService,
    KorailServiceError,
    NoTrainsError,
    SessionExpiredError,
    KorailServerError,
)
from services.tago_service import (
    TaGoService,
    StationNotFoundError,
    TaGoApiError,
    NoTrainsFoundError,
)

logger = logging.getLogger(__name__)

router = APIRouter()

# 한국 시간대
KST = timezone(timedelta(hours=9))

# 유효한 역 목록
VALID_STATIONS = {
    "서울", "용산", "영등포", "광명", "수서", "수원", "동탄", "평택지제",
    "천안아산", "오송", "대전", "김천구미", "서대구", "동대구", "경산",
    "신경주", "경주", "울산", "물금", "구포", "밀양", "부산",
    "창원중앙", "마산",
    "공주", "익산", "정읍", "광주송정", "나주", "목포",
    "전주", "남원", "순천", "여수엑스포",
    "강릉", "만종", "둔내", "평창", "진부",
    "행신", "청량리", "상봉", "양평",
    "포항",
}


def _validate_params(dep: str, arr: str, date: str, time: str) -> None:
    """검색 파라미터 유효성을 검사한다."""
    if not dep or not dep.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "출발역은 필수 입력값입니다",
            },
        )

    if not arr or not arr.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "도착역은 필수 입력값입니다",
            },
        )

    if dep.strip() == arr.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "출발역과 도착역이 같을 수 없습니다",
            },
        )

    if dep.strip() not in VALID_STATIONS:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": f"유효하지 않은 역명입니다: {dep}",
            },
        )

    if arr.strip() not in VALID_STATIONS:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": f"유효하지 않은 역명입니다: {arr}",
            },
        )

    if not re.match(r"^\d{8}$", date):
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "날짜 형식이 올바르지 않습니다 (YYYYMMDD)",
            },
        )

    try:
        search_date = datetime.strptime(date, "%Y%m%d").date()
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "날짜 형식이 올바르지 않습니다 (YYYYMMDD)",
            },
        )

    today = datetime.now(KST).date()
    if search_date < today:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "과거 날짜는 조회할 수 없습니다",
            },
        )

    if not re.match(r"^\d{6}$", time):
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "시간 형식이 올바르지 않습니다 (HHmmss)",
            },
        )

    hour = int(time[:2])
    minute = int(time[2:4])
    if hour > 23 or minute > 59:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "시간 형식이 올바르지 않습니다 (HHmmss)",
            },
        )


@router.get(
    "/search",
    response_model=TrainSearchResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 파라미터"},
        401: {"model": ErrorResponse, "description": "세션 만료 (korail2 모드)"},
        404: {"model": ErrorResponse, "description": "열차 없음"},
        503: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="열차 시간표 조회",
    description=(
        "korail2를 통해 열차를 조회한다 (로그인 필요). "
        "미로그인 시 TAGO 공공데이터로 폴백하지만, "
        "예약을 위해서는 korail2 조회 결과를 사용해야 한다."
    ),
)
async def search_trains(
    dep: str = Query(..., description="출발역 이름 (한글)", examples=["서울"]),
    arr: str = Query(..., description="도착역 이름 (한글)", examples=["부산"]),
    date: str = Query(
        ..., description="출발 날짜 (YYYYMMDD)", examples=["20260205"]
    ),
    time: str = Query(
        ..., description="출발 시간 (HHmmss)", examples=["090000"]
    ),
    authorization: str = Header(None),
    korail_service: KorailService = Depends(get_korail_service),
    tago_service: TaGoService = Depends(get_tago_service),
):
    """
    열차 시간표를 조회한다.

    로그인 상태이면 korail2를 통해 조회 (좌석 정보 포함, 예약 가능).
    미로그인 상태이면 TAGO 공공데이터로 폴백 (좌석 정보 없음).
    """
    _validate_params(dep, arr, date, time)

    logger.info(
        "[Trains] 열차 조회 요청 - %s -> %s, %s %s",
        dep, arr, date, time,
    )

    now = datetime.now(KST)

    # korail2 세션이 유효하면 korail2로 조회 (예약과 동일한 열차번호 체계)
    if authorization and korail_service.is_session_valid():
        try:
            trains = await korail_service.search_trains(dep, arr, date, time)

            response = TrainSearchResponse(
                trains=trains,
                searched_at=now.isoformat(),
            )

            logger.info("[Trains] korail2 조회 성공 - %d건", len(trains))
            return response

        except NoTrainsError as e:
            logger.info("[Trains] korail2 열차 없음: %s", e.detail)
            raise HTTPException(
                status_code=404,
                detail={
                    "error": e.error,
                    "code": e.code,
                    "detail": e.detail,
                },
            )

        except SessionExpiredError as e:
            logger.warning("[Trains] korail2 세션 만료, TAGO 폴백: %s", e.detail)
            # 세션 만료 시 TAGO로 폴백

        except KorailServerError as e:
            logger.warning("[Trains] korail2 서버 오류, TAGO 폴백: %s", e.detail)
            # 코레일 서버 오류 시 TAGO로 폴백

        except Exception as e:
            logger.warning("[Trains] korail2 조회 실패, TAGO 폴백: %s", str(e))
            # 기타 오류 시 TAGO로 폴백

    # TAGO 공공데이터 폴백
    logger.info("[Trains] TAGO 폴백 조회")
    try:
        trains = await tago_service.search_trains(dep, arr, date, time)

        response = TrainSearchResponse(
            trains=trains,
            searched_at=now.isoformat(),
        )

        logger.info("[Trains] TAGO 조회 성공 - %d건", len(trains))
        return response

    except StationNotFoundError as e:
        logger.warning("[Trains] 역명 오류: %s", e.detail)
        raise HTTPException(
            status_code=400,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except NoTrainsFoundError as e:
        logger.info("[Trains] 열차 없음: %s", e.detail)
        raise HTTPException(
            status_code=404,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except TaGoApiError as e:
        logger.error("[Trains] TAGO API 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except Exception as e:
        logger.error("[Trains] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )
