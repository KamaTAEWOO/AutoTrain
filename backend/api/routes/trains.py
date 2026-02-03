"""
열차 조회 API 라우트
GET /api/trains/search - TAGO 공공데이터 API를 통한 열차 시간표 조회
"""

import logging
import re
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from api.deps import get_tago_service
from models.schemas import TrainSearchResponse, ErrorResponse
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
    """
    검색 파라미터 유효성을 검사한다.

    Args:
        dep: 출발역
        arr: 도착역
        date: 날짜 (YYYYMMDD)
        time: 시간 (HHmmss)

    Raises:
        HTTPException(400): 파라미터가 유효하지 않은 경우
    """
    # 출발역 필수
    if not dep or not dep.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "출발역은 필수 입력값입니다",
            },
        )

    # 도착역 필수
    if not arr or not arr.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "도착역은 필수 입력값입니다",
            },
        )

    # 출발역/도착역 동일 불가
    if dep.strip() == arr.strip():
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "출발역과 도착역이 같을 수 없습니다",
            },
        )

    # 유효한 역명 확인
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

    # 날짜 형식 검증 (YYYYMMDD)
    if not re.match(r"^\d{8}$", date):
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "날짜 형식이 올바르지 않습니다 (YYYYMMDD)",
            },
        )

    # 날짜 유효성 검증
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

    # 과거 날짜 검증
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

    # 미래 날짜 범위 검증 (TAGO API는 약 7일 이내만 데이터 제공)
    max_date = today + timedelta(days=7)
    if search_date > max_date:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "DATE_RANGE_EXCEEDED",
                "code": "SEARCH_004",
                "detail": f"공공데이터 API는 {max_date.strftime('%m/%d')}까지만 조회 가능합니다",
            },
        )

    # 시간 형식 검증 (HHmmss)
    if not re.match(r"^\d{6}$", time):
        raise HTTPException(
            status_code=400,
            detail={
                "error": "INVALID_PARAMS",
                "code": "SEARCH_001",
                "detail": "시간 형식이 올바르지 않습니다 (HHmmss)",
            },
        )

    # 시간 범위 검증
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
        404: {"model": ErrorResponse, "description": "열차 없음"},
        503: {"model": ErrorResponse, "description": "API 서버 오류"},
    },
    summary="열차 시간표 조회",
    description=(
        "TAGO 공공데이터 API를 통해 출발역/도착역/날짜/시간 조건으로 "
        "열차 시간표를 조회한다. 인증 불필요."
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
    service: TaGoService = Depends(get_tago_service),
):
    """
    TAGO 공공데이터 API를 통해 열차 시간표를 조회한다.

    - **dep**: 출발역 (한글 역명)
    - **arr**: 도착역 (한글 역명)
    - **date**: 출발 날짜 (YYYYMMDD 형식)
    - **time**: 출발 시간 이후 (HHmmss 형식)

    좌석 유무(general_seats/special_seats)는 공공데이터에서 제공하지 않아
    항상 false로 반환된다. 좌석 확인은 예약 시 별도 확인이 필요하다.
    """
    # 파라미터 유효성 검사
    _validate_params(dep, arr, date, time)

    logger.info(
        "[Trains] 열차 조회 요청 - %s -> %s, %s %s",
        dep, arr, date, time,
    )

    try:
        trains = await service.search_trains(dep, arr, date, time)

        now = datetime.now(KST)

        response = TrainSearchResponse(
            trains=trains,
            searched_at=now.isoformat(),
        )

        logger.info("[Trains] 조회 성공 - %d건", len(trains))
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
