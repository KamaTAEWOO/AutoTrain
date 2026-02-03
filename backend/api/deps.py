"""
의존성 주입 (Dependency Injection)
FastAPI의 Depends를 통해 서비스 인스턴스를 라우트에 주입한다.
"""

import logging

from fastapi import Depends, Header, HTTPException

from services.korail_service import KorailService
from services.tago_service import TaGoService

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# 싱글톤 서비스 인스턴스
# ──────────────────────────────────────────────
_korail_service = KorailService()
_tago_service = TaGoService()


async def get_korail_service() -> KorailService:
    """
    KorailService 싱글톤 인스턴스를 반환한다.

    FastAPI의 Depends()를 통해 라우트 함수에 주입된다.
    """
    return _korail_service


async def get_tago_service() -> TaGoService:
    """
    TaGoService 싱글톤 인스턴스를 반환한다.

    열차 시간표 조회에 사용된다. 인증 불필요.
    """
    return _tago_service


async def verify_session(
    authorization: str = Header(None, description="Bearer {session_token}"),
    service: KorailService = Depends(get_korail_service),
) -> KorailService:
    """
    세션 토큰을 검증하는 의존성.

    Authorization 헤더에서 Bearer 토큰을 추출하고,
    KorailService의 세션 유효성을 확인한다.

    Args:
        authorization: Authorization 헤더 값
        service: KorailService 인스턴스

    Returns:
        KorailService: 세션이 유효한 서비스 인스턴스

    Raises:
        HTTPException(401): 세션이 없거나 만료된 경우
    """
    if not authorization:
        logger.warning("[Auth] Authorization 헤더가 없습니다")
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "AUTH_003",
                "detail": "세션이 만료되었습니다. 다시 로그인해주세요",
            },
        )

    # Bearer 토큰 추출
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        logger.warning("[Auth] 잘못된 Authorization 형식: %s", authorization[:20])
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "AUTH_003",
                "detail": "세션이 만료되었습니다. 다시 로그인해주세요",
            },
        )

    if not service.is_session_valid():
        logger.warning("[Auth] 세션이 만료되었습니다")
        raise HTTPException(
            status_code=401,
            detail={
                "error": "SESSION_EXPIRED",
                "code": "AUTH_003",
                "detail": "세션이 만료되었습니다. 다시 로그인해주세요",
            },
        )

    return service
