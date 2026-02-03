"""
인증 API 라우트
POST /api/auth/login - 코레일 계정 로그인
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from api.deps import get_korail_service
from models.schemas import LoginRequest, LoginResponse, ErrorResponse
from services.korail_service import (
    KorailService,
    LoginFailedError,
    AccountBlockedError,
    KorailServerError,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/login",
    response_model=LoginResponse,
    responses={
        401: {"model": ErrorResponse, "description": "로그인 실패"},
        403: {"model": ErrorResponse, "description": "계정 차단"},
        503: {"model": ErrorResponse, "description": "코레일 서버 오류"},
    },
    summary="코레일 로그인",
    description="코레일 계정으로 로그인하여 세션 토큰을 발급받는다.",
)
async def login(
    request: LoginRequest,
    service: KorailService = Depends(get_korail_service),
):
    """
    코레일 계정으로 로그인한다.

    - **korail_id**: 코레일 멤버십 번호 또는 이메일
    - **korail_pw**: 코레일 비밀번호

    성공 시 session_token을 발급하며, 이후 API 호출 시
    Authorization: Bearer {session_token} 헤더에 포함해야 한다.
    """
    logger.info("[Auth] 로그인 요청 - ID: %s", request.korail_id[:3] + "***")

    try:
        result = await service.login(request.korail_id, request.korail_pw)
        logger.info("[Auth] 로그인 성공")
        return LoginResponse(**result)

    except LoginFailedError as e:
        logger.warning("[Auth] 로그인 실패: %s", e.detail)
        raise HTTPException(
            status_code=401,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except AccountBlockedError as e:
        logger.warning("[Auth] 계정 차단: %s", e.detail)
        raise HTTPException(
            status_code=403,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except KorailServerError as e:
        logger.error("[Auth] 코레일 서버 오류: %s", e.detail)
        raise HTTPException(
            status_code=503,
            detail={
                "error": e.error,
                "code": e.code,
                "detail": e.detail,
            },
        )

    except Exception as e:
        logger.error("[Auth] 알 수 없는 오류: %s", str(e))
        raise HTTPException(
            status_code=500,
            detail={
                "error": "INTERNAL_ERROR",
                "code": "SYSTEM_001",
                "detail": "서버 내부 오류가 발생했습니다",
            },
        )
