"""
Exponential Backoff 재시도 유틸리티
지수 증가 방식으로 실패한 작업을 재시도한다.
스케줄: 5s -> 10s -> 20s -> 40s -> 60s (cap)
"""

import asyncio
import functools
import logging
from typing import Callable, Any, Optional, Type

logger = logging.getLogger(__name__)


def exponential_backoff(
    base_delay: float = 5.0,
    max_delay: float = 60.0,
    max_retries: int = 5,
    retryable_exceptions: Optional[tuple[Type[Exception], ...]] = None,
):
    """
    Exponential backoff 데코레이터.

    실패 시 지수적으로 대기 시간을 증가시키며 재시도한다.
    기본 스케줄: 5 -> 10 -> 20 -> 40 -> 60 (cap)

    Args:
        base_delay: 첫 번째 재시도 대기 시간 (초). 기본값 5.
        max_delay: 최대 대기 시간 (초). 기본값 60.
        max_retries: 최대 재시도 횟수. 기본값 5.
        retryable_exceptions: 재시도할 예외 타입 튜플.
                             None이면 모든 Exception에 대해 재시도.
    """

    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            last_exception = None

            for attempt in range(max_retries + 1):
                try:
                    return await func(*args, **kwargs)
                except Exception as e:
                    last_exception = e

                    # 재시도 가능한 예외인지 확인
                    if retryable_exceptions and not isinstance(e, retryable_exceptions):
                        logger.error(
                            "[Retry] 재시도 불가능한 예외 발생 (attempt %d/%d): %s - %s",
                            attempt + 1,
                            max_retries + 1,
                            type(e).__name__,
                            str(e),
                        )
                        raise

                    # 마지막 시도였으면 예외를 그대로 raise
                    if attempt >= max_retries:
                        logger.error(
                            "[Retry] 최대 재시도 횟수 초과 (%d회): %s - %s",
                            max_retries + 1,
                            type(e).__name__,
                            str(e),
                        )
                        raise

                    # 대기 시간 계산: base_delay * 2^attempt, max_delay로 cap
                    delay = min(base_delay * (2 ** attempt), max_delay)

                    logger.warning(
                        "[Retry] 재시도 %d/%d - %.1f초 후 재시도 예정: %s - %s",
                        attempt + 1,
                        max_retries,
                        delay,
                        type(e).__name__,
                        str(e),
                    )

                    await asyncio.sleep(delay)

            # 이론상 도달하지 않지만 안전장치
            raise last_exception  # type: ignore[misc]

        return wrapper

    return decorator


async def retry_with_backoff(
    func: Callable,
    *args: Any,
    base_delay: float = 5.0,
    max_delay: float = 60.0,
    max_retries: int = 5,
    retryable_exceptions: Optional[tuple[Type[Exception], ...]] = None,
    **kwargs: Any,
) -> Any:
    """
    함수형 인터페이스의 exponential backoff 재시도.

    데코레이터 대신 직접 함수를 호출할 때 사용한다.

    Args:
        func: 실행할 비동기 함수
        *args: 함수에 전달할 위치 인자
        base_delay: 첫 번째 재시도 대기 시간 (초)
        max_delay: 최대 대기 시간 (초)
        max_retries: 최대 재시도 횟수
        retryable_exceptions: 재시도할 예외 타입 튜플
        **kwargs: 함수에 전달할 키워드 인자

    Returns:
        함수 실행 결과
    """
    last_exception = None

    for attempt in range(max_retries + 1):
        try:
            return await func(*args, **kwargs)
        except Exception as e:
            last_exception = e

            if retryable_exceptions and not isinstance(e, retryable_exceptions):
                logger.error(
                    "[Retry] 재시도 불가능한 예외: %s - %s",
                    type(e).__name__,
                    str(e),
                )
                raise

            if attempt >= max_retries:
                logger.error(
                    "[Retry] 최대 재시도 횟수 초과 (%d회): %s - %s",
                    max_retries + 1,
                    type(e).__name__,
                    str(e),
                )
                raise

            delay = min(base_delay * (2 ** attempt), max_delay)

            logger.warning(
                "[Retry] 재시도 %d/%d - %.1f초 후 재시도: %s - %s",
                attempt + 1,
                max_retries,
                delay,
                type(e).__name__,
                str(e),
            )

            await asyncio.sleep(delay)

    raise last_exception  # type: ignore[misc]
