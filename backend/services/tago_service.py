"""
TaGoService - 공공데이터포털(TAGO) 열차정보 API 서비스
국토교통부 열차정보 서비스를 통한 열차 시간표 조회 기능을 제공한다.
"""

import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx

from models.schemas import TrainInfo

logger = logging.getLogger(__name__)

# 한국 시간대 (KST = UTC+9)
KST = timezone(timedelta(hours=9))

# ──────────────────────────────────────────────
# TAGO API 설정
# ──────────────────────────────────────────────
TAGO_BASE_URL = "http://apis.data.go.kr/1613000/TrainInfoService"

# ──────────────────────────────────────────────
# 역명 → NAT 코드 매핑 (주요 KTX 정차역)
# ──────────────────────────────────────────────
STATION_CODES: dict[str, str] = {
    # 서울
    "서울": "NAT010000",
    "용산": "NAT010032",
    "영등포": "NAT010156",
    "청량리": "NAT130126",
    "상봉": "NAT020040",
    "수서": "NATH30000",
    # 경기
    "광명": "NATH10219",
    "수원": "NAT010415",
    "행신": "NAT110147",
    "양평": "NAT020524",
    "동탄": "NATH30326",
    "평택지제": "NATH30536",
    # 충남
    "천안아산": "NATH10960",
    "공주": "NATH20438",
    # 충북
    "오송": "NAT050044",
    # 대전
    "대전": "NAT011668",
    # 경북
    "김천구미": "NATH12383",
    "서대구": "NATH12688",
    "동대구": "NAT013271",
    "경산": "NAT013378",
    "신경주": "NATH13421",
    "경주": "NATH13421",
    "포항": "NAT8B0351",
    # 울산
    "울산(통도사)": "NATH13717",
    # 부산
    "구포": "NAT014152",
    "물금": "NATH13900",
    "부산": "NAT014445",
    # 경남
    "밀양": "NAT013841",
    "창원중앙": "NAT880281",
    "마산": "NAT880345",
    # 전북
    "익산": "NAT030879",
    "정읍": "NAT031314",
    "전주": "NAT040257",
    "남원": "NAT040868",
    # 전남
    "광주송정": "NAT031857",
    "나주": "NAT031998",
    "목포": "NAT032563",
    "순천": "NAT041595",
    "여수EXPO": "NAT041993",
    # 강원
    "강릉": "NAT601936",
    "만종": "NAT021033",
    "둔내": "NATN10428",
    "평창": "NATN10625",
    "진부": "NATN10787",
}

# 역명 별칭 → 실제 역명 매핑
STATION_ALIASES: dict[str, str] = {
    "울산": "울산(통도사)",
    "여수엑스포": "여수EXPO",
    "여수": "여수EXPO",
}

# 차량종류코드 → 열차 종류명 매핑
TRAIN_GRADE_NAMES: dict[str, str] = {
    "00": "KTX",
    "01": "새마을호",
    "02": "무궁화호",
    "03": "통근열차",
    "04": "누리로",
    "06": "공항직통",
    "07": "KTX-이음",
    "08": "SRT",
    "09": "ITX-새마을",
    "10": "ITX-청춘",
    "16": "KTX-산천",
    "17": "SRT",
}


class TaGoServiceError(Exception):
    """TAGO 서비스 기본 예외"""

    def __init__(self, error: str, code: str, detail: str):
        self.error = error
        self.code = code
        self.detail = detail
        super().__init__(detail)


class StationNotFoundError(TaGoServiceError):
    """역명을 찾을 수 없음"""

    def __init__(self, station_name: str):
        super().__init__(
            error="STATION_NOT_FOUND",
            code="SEARCH_001",
            detail=f"역명을 찾을 수 없습니다: {station_name}",
        )


class TaGoApiError(TaGoServiceError):
    """TAGO API 호출 실패"""

    def __init__(self, detail: str = "공공데이터 API 호출에 실패했습니다"):
        super().__init__(
            error="TAGO_API_ERROR",
            code="SEARCH_003",
            detail=detail,
        )


class NoTrainsFoundError(TaGoServiceError):
    """열차 없음"""

    def __init__(self, detail: str = "해당 조건의 열차가 없습니다"):
        super().__init__(
            error="NO_TRAINS",
            code="SEARCH_002",
            detail=detail,
        )


class TaGoService:
    """
    공공데이터포털(TAGO) 열차정보 서비스 클래스.

    기능:
    - 출/도착지 기반 열차 시간표 조회
    - 역명 → NAT 코드 변환
    - 차량종류 목록 조회
    """

    def __init__(self, api_key: Optional[str] = None):
        self._api_key = api_key or os.getenv("TAGO_API_KEY", "")
        if not self._api_key:
            logger.warning("[TaGoService] TAGO_API_KEY가 설정되지 않았습니다")

        self._client = httpx.AsyncClient(timeout=10.0)
        logger.info("[TaGoService] 서비스 초기화 완료")

    def _resolve_station(self, name: str) -> str:
        """
        역명을 NAT 코드로 변환한다.
        별칭도 지원한다 (울산 → 울산(통도사) 등).

        Raises:
            StationNotFoundError: 역명을 찾을 수 없는 경우
        """
        resolved = STATION_ALIASES.get(name, name)
        code = STATION_CODES.get(resolved)
        if code is None:
            raise StationNotFoundError(name)
        return code

    async def search_trains(
        self,
        dep: str,
        arr: str,
        date: str,
        time: Optional[str] = None,
        train_grade_code: Optional[str] = None,
    ) -> list[TrainInfo]:
        """
        출발역/도착역/날짜 조건으로 열차 시간표를 조회한다.

        Args:
            dep: 출발역 이름 (한글)
            arr: 도착역 이름 (한글)
            date: 출발 날짜 (YYYYMMDD)
            time: 출발 시간 필터 (HHmmss, 이 시간 이후만 반환). None이면 전체.
            train_grade_code: 차량종류코드 (예: "00"=KTX). None이면 전체.

        Returns:
            list[TrainInfo]: 열차 정보 목록

        Raises:
            StationNotFoundError: 역명을 찾을 수 없는 경우
            TaGoApiError: TAGO API 호출 실패
            NoTrainsFoundError: 해당 조건의 열차 없음
        """
        dep_code = self._resolve_station(dep)
        arr_code = self._resolve_station(arr)

        logger.info(
            "[TaGoService] 열차 조회 - %s(%s) -> %s(%s), %s",
            dep, dep_code, arr, arr_code, date,
        )

        params: dict[str, str] = {
            "serviceKey": self._api_key,
            "depPlaceId": dep_code,
            "arrPlaceId": arr_code,
            "depPlandTime": date,
            "numOfRows": "100",
            "pageNo": "1",
            "_type": "json",
        }
        if train_grade_code:
            params["trainGradeCode"] = train_grade_code

        try:
            resp = await self._client.get(
                f"{TAGO_BASE_URL}/getStrtpntAlocFndTrainInfo",
                params=params,
            )
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPStatusError as e:
            logger.error("[TaGoService] HTTP 오류: %s", e)
            raise TaGoApiError(detail=f"API HTTP 오류: {e.response.status_code}")
        except httpx.RequestError as e:
            logger.error("[TaGoService] 요청 오류: %s", e)
            raise TaGoApiError(detail="공공데이터 API에 연결할 수 없습니다")
        except Exception as e:
            logger.error("[TaGoService] 파싱 오류: %s", e)
            raise TaGoApiError(detail=f"API 응답 파싱 실패: {e}")

        # 응답 구조 파싱
        header = data.get("response", {}).get("header", {})
        result_code = header.get("resultCode", "")
        if result_code != "00":
            result_msg = header.get("resultMsg", "알 수 없는 오류")
            logger.error(
                "[TaGoService] API 에러 - code=%s, msg=%s",
                result_code, result_msg,
            )
            raise TaGoApiError(detail=f"TAGO API 오류: [{result_code}] {result_msg}")

        body = data.get("response", {}).get("body", {})
        total_count = body.get("totalCount", 0)
        if total_count == 0:
            raise NoTrainsFoundError()

        items = body.get("items", {})
        if not items or items == "":
            raise NoTrainsFoundError()

        item_list = items.get("item", [])
        # 단일 항목인 경우 리스트로 변환
        if isinstance(item_list, dict):
            item_list = [item_list]

        train_list: list[TrainInfo] = []
        for item in item_list:
            try:
                train_info = self._parse_train_item(item)

                # 시간 필터: 지정된 시간 이후의 열차만 포함
                if time:
                    dep_pland = str(item.get("depplandtime", ""))
                    if len(dep_pland) >= 12:
                        dep_hhmm = dep_pland[8:12]  # HHmm 부분
                        filter_hhmm = time[:4]  # HHmm 부분
                        if dep_hhmm < filter_hhmm:
                            continue

                train_list.append(train_info)
            except Exception as e:
                logger.warning(
                    "[TaGoService] 열차 정보 파싱 오류 (건너뜀): %s", e,
                )
                continue

        if not train_list:
            raise NoTrainsFoundError()

        logger.info("[TaGoService] 조회 완료 - %d건", len(train_list))
        return train_list

    @staticmethod
    def _parse_train_item(item: dict) -> TrainInfo:
        """TAGO API 응답 항목을 TrainInfo로 변환한다."""
        dep_pland = str(item.get("depplandtime", ""))
        arr_pland = str(item.get("arrplandtime", ""))

        # YYYYMMDDHHMISS → HH:mm
        dep_time = f"{dep_pland[8:10]}:{dep_pland[10:12]}" if len(dep_pland) >= 12 else "00:00"
        arr_time = f"{arr_pland[8:10]}:{arr_pland[10:12]}" if len(arr_pland) >= 12 else "00:00"

        train_no = str(item.get("trainno", "N/A"))
        train_grade = str(item.get("traingradename", ""))

        adult_charge = item.get("adultcharge")
        charge_val: Optional[int] = None
        if adult_charge is not None:
            try:
                charge_val = int(adult_charge)
            except (ValueError, TypeError):
                pass

        return TrainInfo(
            train_no=train_no,
            train_type=train_grade,
            dep_station=str(item.get("depplacename", "")),
            arr_station=str(item.get("arrplacename", "")),
            dep_time=dep_time,
            arr_time=arr_time,
            general_seats=None,  # TAGO API는 좌석 유무 미제공
            special_seats=None,
            adult_charge=charge_val,
        )

    @staticmethod
    def get_station_code(name: str) -> Optional[str]:
        """역명으로 NAT 코드를 조회한다. 없으면 None."""
        resolved = STATION_ALIASES.get(name, name)
        return STATION_CODES.get(resolved)

    @staticmethod
    def get_all_stations() -> dict[str, str]:
        """전체 역명 → NAT 코드 매핑을 반환한다."""
        return dict(STATION_CODES)

    async def close(self):
        """HTTP 클라이언트를 닫는다."""
        await self._client.aclose()
