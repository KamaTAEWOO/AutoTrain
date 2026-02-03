"""
Pydantic 요청/응답 스키마 정의
KTX 자동 조회/예약 API의 모든 데이터 모델을 정의한다.
"""

from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum


# ──────────────────────────────────────────────
# Enum 정의
# ──────────────────────────────────────────────

class SeatType(str, Enum):
    """좌석 유형"""
    GENERAL = "general"
    SPECIAL = "special"


# ──────────────────────────────────────────────
# 요청 모델
# ──────────────────────────────────────────────

class LoginRequest(BaseModel):
    """로그인 요청"""
    korail_id: str = Field(..., description="코레일 멤버십 번호 또는 이메일")
    korail_pw: str = Field(..., description="코레일 비밀번호")


class ReservationRequest(BaseModel):
    """예약 요청"""
    train_no: str = Field(..., description="예약할 열차 번호")
    seat_type: SeatType = Field(
        default=SeatType.GENERAL,
        description='좌석 유형: "general" (일반실), "special" (특실)'
    )
    dep_station: str = Field(..., description="출발역")
    arr_station: str = Field(..., description="도착역")
    date: str = Field(..., description="출발 날짜 (YYYYMMDD)")
    time: str = Field(default="000000", description="출발 시간 (HHmmss)")


# ──────────────────────────────────────────────
# 응답 모델
# ──────────────────────────────────────────────

class LoginResponse(BaseModel):
    """로그인 응답"""
    session_token: str = Field(..., description="세션 토큰")
    expires_at: str = Field(..., description="세션 만료 시각 (ISO 8601)")
    name: str = Field(default="", description="회원 이름")
    message: str = Field(default="로그인 성공", description="결과 메시지")


class TrainInfo(BaseModel):
    """열차 정보"""
    train_no: str = Field(..., description="열차 번호")
    train_type: str = Field(..., description="열차 종류 (KTX, KTX-산천 등)")
    dep_station: str = Field(..., description="출발역")
    arr_station: str = Field(..., description="도착역")
    dep_time: str = Field(..., description="출발 시간 (HH:mm)")
    arr_time: str = Field(..., description="도착 시간 (HH:mm)")
    general_seats: Optional[bool] = Field(None, description="일반실 좌석 여부 (true: 있음, null: 미확인)")
    special_seats: Optional[bool] = Field(None, description="특실 좌석 여부 (true: 있음, null: 미확인)")
    adult_charge: Optional[int] = Field(None, description="일반석 운임 (원, TAGO 조회 시)")


class TrainSearchResponse(BaseModel):
    """열차 조회 응답"""
    trains: list[TrainInfo] = Field(default_factory=list, description="열차 정보 배열")
    searched_at: str = Field(..., description="조회 시각 (ISO 8601)")


class ReservationResponse(BaseModel):
    """예약 응답"""
    reservation_id: str = Field(..., description="예약 번호")
    status: str = Field(..., description='예약 상태 ("success")')
    train: TrainInfo = Field(..., description="예약된 열차 정보")
    message: str = Field(..., description="결과 메시지 (결제 안내 포함)")
    reserved_at: str = Field(..., description="예약 시각 (ISO 8601)")


class ReservationDetailResponse(BaseModel):
    """예약 상세 조회 응답"""
    reservation_id: str = Field(..., description="예약 번호")
    status: str = Field(..., description="예약 상태")
    train: TrainInfo = Field(..., description="예약된 열차 정보")
    reserved_at: str = Field(..., description="예약 시각 (ISO 8601)")
    payment_deadline: Optional[str] = Field(
        None,
        description="결제 기한 (ISO 8601, 예약 후 10분)"
    )


class ReservationListResponse(BaseModel):
    """예약 목록 조회 응답"""
    reservations: list[ReservationDetailResponse] = Field(
        default_factory=list, description="예약 목록"
    )
    count: int = Field(..., description="예약 건수")


class CancellationResponse(BaseModel):
    """예약 취소 응답"""
    reservation_id: str = Field(..., description="예약 번호")
    status: str = Field(..., description='취소 상태 ("cancelled")')
    message: str = Field(..., description="결과 메시지")
    cancelled_at: str = Field(..., description="취소 시각 (ISO 8601)")


class ErrorResponse(BaseModel):
    """에러 응답 (공통 포맷)"""
    error: str = Field(..., description="에러 타입 (대문자 SNAKE_CASE)")
    code: str = Field(..., description="에러 코드 (카테고리_숫자 3자리)")
    detail: str = Field(..., description="사용자에게 표시 가능한 에러 설명 (한국어)")
