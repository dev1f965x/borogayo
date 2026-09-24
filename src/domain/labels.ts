import type { Kind, Scope } from "./criteria";
import { about } from "./korean";

export const APP_NAME = "보러가요";

export const SCOPE_LABELS: Record<Scope, string> = {
  building: "건물",
  room: "방",
};

export const SCOPE_HINTS: Record<Scope, string> = {
  building: "같은 건물이면 한 번만 매겨요",
  room: "방마다 따로 매겨요",
};

export const KIND_LABELS: Record<Kind, string> = {
  scale: "점수",
  yesNo: "예·아니오",
};

export const KIND_HINTS: Record<Kind, string> = {
  scale: "0~10점으로 매겨요",
  yesNo: "예, 아니오로 답해요",
};

export const HUNT_LABELS = {
  heading: "집 구하기",
  empty: "아직 시작한 게 없어요",
  emptyDetail: "먼저 무엇을 볼지 정해 두면, 보러 다닐 때는 점수만 매기면 돼요.",
  start: "새로 시작하기",
  namePlaceholder: "2026년 봄 이사",
  rename: "이름 바꾸기",
  remove: (name: string) => `"${name}" 지우기`,
  removed: (name: string) => `"${name}" 지웠어요`,
  places: (buildings: number, rooms: number) => `건물 ${buildings} · 방 ${rooms}`,
  startedOn: (day: string) => `${day}부터`,
};

export const CRITERIA_LABELS = {
  heading: "볼 것 정하기",
  intro: "보러 가기 전에 정해 두면, 현장에서는 점수만 매기면 돼요.",
  add: "항목 추가",
  namePlaceholder: "무엇을 볼까요",
  weight: "중요도",
  weightOf: (weight: number) => `중요도 ${weight}`,
  scope: "어디에 매겨요",
  kind: "어떻게 매겨요",
  remove: (name: string) => `${name} 지우기`,
  removed: (name: string) => `${name} 지웠어요`,
  up: "위로",
  down: "아래로",
  empty: "볼 것을 하나도 안 정했어요",
  emptyDetail: "하나만 정해도 점수를 매길 수 있어요.",
  keepsForNext: "여기서 고친 항목이 다음에 시작할 때 기본이 돼요",
};

export const PLACE_LABELS = {
  addBuilding: "건물 추가",
  addRoom: "방 추가",
  buildingPlaceholder: "○○빌라, 큰길 옆 오피스텔",
  roomPlaceholder: "301호, 2층 왼쪽",
  memo: "메모",
  memoPlaceholder: "집주인이 말한 것, 계약 조건, 신경 쓰이는 것",
  removeRoom: (name: string) => `${name} 지우기`,
  removedRoom: (name: string) => `${name} 지웠어요`,
  buildingOnly: (name: string) => `${name}에 아직 방이 없어요`,
  undo: "되돌리기",
};

export const SCORE_LABELS = {
  skip: "해당 없음",
  skipped: "해당 없음으로 뒀어요",
  yes: "예",
  no: "아니오",
  ofTen: (value: number) => `${trim(value)}점`,
  unanswered: "아직",
  open: (count: number) => `${count}개 남았어요`,
  done: "다 매겼어요",
  buildingShared: (name: string) => `${about(name)} 같은 건물 방마다 같이 적용돼요`,
};

export const BOARD_LABELS = {
  heading: "순위",
  empty: "아직 본 곳이 없어요",
  emptyDetail: "보고 온 곳을 추가하고 점수를 매기면 여기에 순서대로 모여요.",
  noScore: "—",
  rank: (place: number) => `${place}위`,
  percent: (value: number) => `${Math.round(value)}%`,
  compare: "나란히 보기",
  comparePick: "비교할 방을 2~3개 고르세요",
  comparing: (count: number) => `${count}개 고름`,
  stopComparing: "그만 보기",
};

export const COMPARE_LABELS = {
  heading: "나란히 보기",
  best: "제일 나음",
  tie: "같음",
  total: "총점",
  need: "방을 2개 이상 고르면 비교할 수 있어요",
};

export const PHOTO_LABELS = {
  add: "사진",
  heading: "사진",
  area: "어디를 찍었어요",
  remove: "사진 지우기",
  removed: "사진 지웠어요",
  none: "아직 없어요",
  stripped: "위치와 기기 정보는 지우고 저장해요",
  buildingAreas: ["외관", "공용부", "주차장", "주변"],
  roomAreas: ["거실", "방", "주방", "화장실", "베란다", "현관"],
};

/** 0.5 steps read better without a trailing zero: 7점, 7.5점. */
function trim(value: number): string {
  return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}

/** A hunt's date, said the way it would be said out loud. */
export function describeDay(day: string): string {
  const date = new Date(`${day}T00:00:00`);
  return `${date.getFullYear()}년 ${date.getMonth() + 1}월`;
}

/** What a criterion is, in one line, for the list that shows them all. */
export function describeCriterion(scope: Scope, kind: Kind, weight: number): string {
  return `${SCOPE_LABELS[scope]} · ${KIND_LABELS[kind]} · ${CRITERIA_LABELS.weightOf(weight)}`;
}
