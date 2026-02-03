"""
KTX 자동 조회/예약 API 서버
FastAPI 앱 생성, CORS 설정, 라우터 등록, 글로벌 예외 핸들러를 구성한다.
"""

import logging
import os
import sys

from dotenv import load_dotenv

# ──────────────────────────────────────────────
# 환경변수 로드 (라우터/서비스 import 전에 실행해야 함)
# ──────────────────────────────────────────────
load_dotenv()

from fastapi import FastAPI, Request  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402
from starlette.middleware.base import BaseHTTPMiddleware  # noqa: E402

from api.routes.auth import router as auth_router  # noqa: E402
from api.routes.trains import router as trains_router  # noqa: E402
from api.routes.reservation import router as reservation_router  # noqa: E402
from services.korail_service import KorailServiceError  # noqa: E402
from services.tago_service import TaGoServiceError  # noqa: E402

# ──────────────────────────────────────────────
# 로깅 설정
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# FastAPI 앱 생성
# ──────────────────────────────────────────────
app = FastAPI(
    title="KTX Auto Reservation API",
    description=(
        "KTX 열차 자동 조회 및 예약 테스트 API.\n\n"
        "TAGO 공공데이터 API로 열차 시간표를 조회하고, "
        "korail2 비공식 API로 예약을 수행한다."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ──────────────────────────────────────────────
# CORS 미들웨어 (Flutter 앱에서의 요청 허용)
# ──────────────────────────────────────────────
_cors_origins = os.getenv(
    "CORS_ORIGINS",
    "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000",
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in _cors_origins],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────
# 요청 디버그 로깅 미들웨어
# ──────────────────────────────────────────────

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        body = b""
        if request.method in ("POST", "PUT", "PATCH"):
            body = await request.body()
        logger.info(
            "[REQ] %s %s | body=%s",
            request.method,
            request.url.path,
            body[:500].decode("utf-8", errors="replace") if body else "-",
        )
        response = await call_next(request)
        logger.info(
            "[RES] %s %s → %d",
            request.method,
            request.url.path,
            response.status_code,
        )
        return response

app.add_middleware(RequestLoggingMiddleware)

# ──────────────────────────────────────────────
# 라우터 등록
# ──────────────────────────────────────────────
app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
app.include_router(trains_router, prefix="/api/trains", tags=["trains"])
app.include_router(reservation_router, prefix="/api", tags=["reservation"])

logger.info("라우터 등록 완료: /api/auth, /api/trains, /api/reservation")

# ──────────────────────────────────────────────
# 글로벌 예외 핸들러
# ──────────────────────────────────────────────


@app.exception_handler(KorailServiceError)
async def korail_exception_handler(
    request: Request, exc: KorailServiceError
) -> JSONResponse:
    """
    KorailServiceError 계열 예외를 잡아 표준 에러 응답 포맷으로 반환한다.

    라우트에서 개별 처리하지 못한 KorailServiceError가 여기서 처리된다.
    """
    logger.error(
        "[GlobalHandler] KorailServiceError: %s (code=%s, error=%s)",
        exc.detail,
        exc.code,
        exc.error,
    )

    # 에러 코드에 따라 HTTP 상태 코드 매핑
    status_code_map = {
        "AUTH_001": 401,   # 로그인 실패
        "AUTH_002": 403,   # 계정 차단
        "AUTH_003": 401,   # 세션 만료
        "SEARCH_001": 400, # 잘못된 파라미터
        "SEARCH_002": 404, # 열차 없음
        "SEARCH_003": 503, # 코레일 서버 오류
        "RESERVE_001": 409, # 매진
        "RESERVE_002": 401, # 세션 만료
        "RESERVE_003": 404, # 예약 없음
        "SYSTEM_001": 500, # 내부 서버 오류
        "SYSTEM_002": 503, # 코레일 서버 오류
        "SYSTEM_003": 504, # 요청 시간 초과
    }

    status_code = status_code_map.get(exc.code, 500)

    return JSONResponse(
        status_code=status_code,
        content={
            "error": exc.error,
            "code": exc.code,
            "detail": exc.detail,
        },
    )


@app.exception_handler(TaGoServiceError)
async def tago_exception_handler(
    request: Request, exc: TaGoServiceError
) -> JSONResponse:
    """
    TaGoServiceError 계열 예외를 잡아 표준 에러 응답 포맷으로 반환한다.
    """
    logger.error(
        "[GlobalHandler] TaGoServiceError: %s (code=%s, error=%s)",
        exc.detail,
        exc.code,
        exc.error,
    )

    status_code_map = {
        "SEARCH_001": 400,  # 역명 오류
        "SEARCH_002": 404,  # 열차 없음
        "SEARCH_003": 503,  # TAGO API 오류
    }

    status_code = status_code_map.get(exc.code, 500)

    return JSONResponse(
        status_code=status_code,
        content={
            "error": exc.error,
            "code": exc.code,
            "detail": exc.detail,
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """
    처리되지 않은 모든 예외를 잡아 표준 에러 응답 포맷으로 반환한다.
    """
    logger.error(
        "[GlobalHandler] Unhandled Exception: %s - %s",
        type(exc).__name__,
        str(exc),
    )

    return JSONResponse(
        status_code=500,
        content={
            "error": "INTERNAL_ERROR",
            "code": "SYSTEM_001",
            "detail": "서버 내부 오류가 발생했습니다",
        },
    )


# ──────────────────────────────────────────────
# 헬스체크 엔드포인트
# ──────────────────────────────────────────────


@app.get(
    "/health",
    tags=["system"],
    summary="헬스체크",
    description="서버 상태를 확인한다.",
)
async def health_check():
    """서버 상태 확인용 헬스체크 엔드포인트."""
    return {"status": "ok", "service": "KTX Auto Reservation API"}


# ──────────────────────────────────────────────
# 앱 이벤트
# ──────────────────────────────────────────────


@app.on_event("startup")
async def startup_event():
    """서버 시작 시 실행되는 이벤트 핸들러."""
    logger.info("=" * 60)
    logger.info("KTX Auto Reservation API 서버 시작")
    logger.info("  Swagger UI: http://localhost:%s/docs", os.getenv("PORT", "8000"))
    logger.info("  ReDoc:      http://localhost:%s/redoc", os.getenv("PORT", "8000"))
    logger.info("=" * 60)


@app.on_event("shutdown")
async def shutdown_event():
    """서버 종료 시 실행되는 이벤트 핸들러."""
    from api.deps import _tago_service
    await _tago_service.close()
    logger.info("KTX Auto Reservation API 서버 종료")


# ──────────────────────────────────────────────
# 직접 실행 시 uvicorn 구동
# ──────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "true").lower() == "true"

    logger.info("서버 시작: %s:%d (reload=%s)", host, port, debug)

    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
    )
