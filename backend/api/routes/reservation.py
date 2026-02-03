"""
예약 API 라우트
POST   /api/reservation           - 예약 생성
GET    /api/reservation/{id}      - 예약 상세 조회
DELETE /api/reservation/{id}      - 예약 취소
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from api.deps import verify_session
from models.schemas import (
    ReservationRequest,
    ReservationResponse,
    ReservationDetailResponse,
    ReservationListResponse,
    CancellationResponse,
    ErrorResponse,
)
from services.korail_service import (
    KorailService,
    SessionExpiredError,
    SoldOutError,
    KorailServerError,
    ReservationNotFoundError,
    CancellationFailedError,
    NoTrainsError,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/reservation",
    response_model=ReservationResponse,
    responses={
        401: {"model": ErrorResponse, "description": "세션 만료"},
        409: {"model": ErrorResponse, "description": "매진"},
        503: {"model": ErrorResponse, "description": "코레일 서버 오류"},
    },
    summary="예약 생성",
    description="선택한 열차에 대해 예약을 시도한다. 결제는 포함하지 않는다.",
)
async def create_reservation(
    request: ReservationRequest,
    service: KorailService = Depends(verify_session),
):
    """
    선택한 열차에 대해 예약을 시도한다.

    - **train_no**: 예약할 열차 번호 (조회 결과의 train_no)
    - **seat_type**: 좌석 유형 ("general" 또는 "special")

    Authorization: Bearer {session_token} 헤더가 필요하다.
    예약만 생성하며, 결제는 별도로 진행해야 한다 (10분 내 결제 필요).
    """
    logger.info(
        "[Reservation] 예약 요청 - 열차: %s, 좌석: %s",
        request.train_no,
        request.seat_type.value,
    )

    try:
        result = await service.reserve(
            request.train_no,
            request.seat_type.value,
            dep=request.dep_station,
            arr=request.arr_station,
            date=request.date,
            time=request.time,
        )

        logger.info(
            "[Reservation] 예약 성공 - 예약번호: %s", result.reservation_id
        )
        return result

    except SessionExpiredError as e:
        logger.warning("[Reservation] 세션 만료: %s", e.detail)
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "RESERVE_002",
                "detail": "세션이 만료되었습니다",
            },
        )

    except SoldOutError as e:
        logger.info("[Reservation] 매진: %s", e.detail)
        raise HTTPException(
            status_code=409,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except NoTrainsError as e:
        logger.warning("[Reservation] 열차 없음: %s", e.detail)
        raise HTTPException(
            status_code=404,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except KorailServerError as e:
        logger.error("[Reservation] 코레일 서버 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "KORAIL_SERVER_ERROR",
                "code": "SYSTEM_002",
                "detail": "코레일 서버와 통신할 수 없습니다",
            },
        )

    except Exception as e:
        logger.error("[Reservation] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )


@router.get(
    "/reservation",
    response_model=ReservationListResponse,
    responses={
        401: {"model": ErrorResponse, "description": "세션 만료"},
        503: {"model": ErrorResponse, "description": "코레일 서버 오류"},
    },
    summary="예약 목록 조회",
    description="현재 계정의 모든 예약 목록을 조회한다.",
)
async def list_reservations(
    service: KorailService = Depends(verify_session),
):
    """
    현재 계정의 모든 예약 목록을 조회한다.

    Authorization: Bearer {session_token} 헤더가 필요하다.
    """
    logger.info("[Reservation] 예약 목록 조회")

    try:
        reservations = await service.list_reservations()

        logger.info("[Reservation] 예약 목록 조회 성공 - %d건", len(reservations))
        return ReservationListResponse(
            reservations=reservations,
            count=len(reservations),
        )

    except SessionExpiredError as e:
        logger.warning("[Reservation] 세션 만료: %s", e.detail)
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "RESERVE_002",
                "detail": "세션이 만료되었습니다",
            },
        )

    except KorailServerError as e:
        logger.error("[Reservation] 코레일 서버 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "KORAIL_SERVER_ERROR",
                "code": "SYSTEM_002",
                "detail": "코레일 서버와 통신할 수 없습니다",
            },
        )

    except Exception as e:
        logger.error("[Reservation] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )


@router.get(
    "/reservation/{reservation_id}",
    response_model=ReservationDetailResponse,
    responses={
        401: {"model": ErrorResponse, "description": "세션 만료"},
        404: {"model": ErrorResponse, "description": "예약 없음"},
    },
    summary="예약 상세 조회",
    description="예약 번호로 예약 상세 정보를 조회한다.",
)
async def get_reservation(
    reservation_id: str,
    service: KorailService = Depends(verify_session),
):
    """
    예약 번호로 예약 상세 정보를 조회한다.

    - **reservation_id**: 예약 번호

    Authorization: Bearer {session_token} 헤더가 필요하다.
    """
    logger.info("[Reservation] 예약 조회 - ID: %s", reservation_id)

    try:
        result = await service.get_reservation(reservation_id)

        logger.info("[Reservation] 예약 조회 성공")
        return result

    except SessionExpiredError as e:
        logger.warning("[Reservation] 세션 만료: %s", e.detail)
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "RESERVE_002",
                "detail": "세션이 만료되었습니다",
            },
        )

    except ReservationNotFoundError as e:
        logger.info("[Reservation] 예약 없음: %s", e.detail)
        raise HTTPException(
            status_code=404,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except KorailServerError as e:
        logger.error("[Reservation] 코레일 서버 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "KORAIL_SERVER_ERROR",
                "code": "SYSTEM_002",
                "detail": "코레일 서버와 통신할 수 없습니다",
            },
        )

    except Exception as e:
        logger.error("[Reservation] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )


@router.delete(
    "/reservation/{reservation_id}",
    response_model=CancellationResponse,
    responses={
        401: {"model": ErrorResponse, "description": "세션 만료"},
        404: {"model": ErrorResponse, "description": "예약 없음"},
        422: {"model": ErrorResponse, "description": "취소 실패"},
        503: {"model": ErrorResponse, "description": "코레일 서버 오류"},
    },
    summary="예약 취소",
    description="예약 번호로 예약을 취소한다.",
)
async def cancel_reservation(
    reservation_id: str,
    service: KorailService = Depends(verify_session),
):
    """
    예약 번호로 예약을 취소한다.

    - **reservation_id**: 취소할 예약 번호

    Authorization: Bearer {session_token} 헤더가 필요하다.
    """
    logger.info("[Reservation] 예약 취소 요청 - ID: %s", reservation_id)

    try:
        result = await service.cancel_reservation(reservation_id)

        logger.info("[Reservation] 예약 취소 성공 - ID: %s", reservation_id)
        return result

    except SessionExpiredError as e:
        logger.warning("[Reservation] 세션 만료: %s", e.detail)
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "RESERVE_002",
                "detail": "세션이 만료되었습니다",
            },
        )

    except ReservationNotFoundError as e:
        logger.info("[Reservation] 예약 없음: %s", e.detail)
        raise HTTPException(
            status_code=404,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except CancellationFailedError as e:
        logger.error("[Reservation] 취소 실패: %s", e.detail)
        raise HTTPException(
            status_code=422,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except KorailServerError as e:
        logger.error("[Reservation] 코레일 서버 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "KORAIL_SERVER_ERROR",
                "code": "SYSTEM_002",
                "detail": "코레일 서버와 통신할 수 없습니다",
            },
        )

    except Exception as e:
        logger.error("[Reservation] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )
