import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it } from "vitest";
import App from "./App";
import type { Criterion } from "./domain/criteria";
import type { Hunt } from "./domain/hunt";
import type { Photos } from "./storage/photos";
import type { Store } from "./storage/store";

const NOW = new Date(2026, 8, 25, 14, 0);

const light: Criterion = {
  id: "light",
  name: "채광",
  emoji: "☀️",
  scope: "room",
  kind: "scale",
  weight: 3,
};
const transit: Criterion = {
  id: "transit",
  name: "교통",
  emoji: "🚇",
  scope: "building",
  kind: "scale",
  weight: 3,
};

function hunt(over: Partial<Hunt> = {}): Hunt {
  return {
    id: "h",
    name: "가을 이사",
    startedOn: "2026-09-25",
    criteria: [light, transit],
    buildings: [],
    rooms: [],
    ...over,
  };
}

function fakeStore(hunts: Hunt[] = [], starting?: Criterion[]): Store {
  let kept = hunts;
  let start = starting;

  return {
    readHunts: () => kept,
    writeHunts: (next) => {
      kept = [...next];
    },
    readStartingCriteria: () => start,
    writeStartingCriteria: (next) => {
      start = [...next];
    },
  };
}

function fakePhotos(): Photos {
  const kept = new Map<string, Blob>();
  return {
    put: async (id, photo) => {
      kept.set(id, photo);
    },
    get: async (id) => kept.get(id),
    remove: async (id) => {
      kept.delete(id);
    },
  };
}

function show(store: Store) {
  return render(<App store={store} photos={fakePhotos()} now={NOW} />);
}

/** The button that opens the hunt, told apart from the one that deletes it. */
function huntNamed(name: string) {
  return screen.getByRole("button", { name: new RegExp(`^${name},`) });
}

describe("a first visit", () => {
  it("asks what the move is, rather than showing an empty ranking", () => {
    show(fakeStore());

    expect(screen.getByText("아직 시작한 게 없어요")).toBeInTheDocument();
  });

  it("opens a new hunt on its criteria", async () => {
    const user = userEvent.setup();
    show(fakeStore());

    await user.type(screen.getByRole("textbox", { name: "새로 시작하기" }), "가을 이사");
    await user.click(screen.getByRole("button", { name: "새로 시작하기" }));

    expect(
      screen.getByText("보러 가기 전에 정해 두면, 현장에서는 점수만 매기면 돼요."),
    ).toBeInTheDocument();
    expect(screen.getByText("교통")).toBeInTheDocument();
  });
});

describe("scoring", () => {
  let user: ReturnType<typeof userEvent.setup>;

  beforeEach(() => {
    user = userEvent.setup();
  });

  async function openRoom(store: Store, room = "301호") {
    show(store);
    await user.click(huntNamed("가을 이사"));
    await user.click(screen.getByRole("button", { name: new RegExp(room) }));
  }

  const oneRoom = () =>
    fakeStore([
      hunt({
        buildings: [{ id: "b", name: "햇살빌라", answers: {}, photos: [] }],
        rooms: [{ id: "r", buildingId: "b", name: "301호", answers: {}, photos: [] }],
      }),
    ]);

  it("says how much is left until the room can be ranked", async () => {
    await openRoom(oneRoom());

    expect(screen.getByText("2개 남았어요")).toBeInTheDocument();
  });

  it("gives a percentage once nothing is open", async () => {
    await openRoom(oneRoom());

    await user.click(within(rowOf("채광")).getByRole("button", { name: "10점" }));
    await user.click(within(rowOf("교통")).getByRole("button", { name: "0점" }));

    expect(screen.getByText("50%")).toBeInTheDocument();
  });

  it("leaves a criterion marked 해당 없음 out of the total", async () => {
    await openRoom(oneRoom());

    await user.click(within(rowOf("채광")).getByRole("button", { name: "10점" }));
    await user.click(within(rowOf("교통")).getByRole("button", { name: "해당 없음" }));

    expect(screen.getByText("100%")).toBeInTheDocument();
  });

  it("takes an answer back off when the same value is tapped again", async () => {
    await openRoom(oneRoom());

    const ten = within(rowOf("채광")).getByRole("button", { name: "10점" });
    await user.click(ten);
    await user.click(ten);

    expect(screen.getByText("2개 남았어요")).toBeInTheDocument();
  });
});

describe("the ranking", () => {
  const threeRooms = () =>
    fakeStore([
      hunt({
        buildings: [{ id: "b", name: "햇살빌라", answers: { transit: 10 }, photos: [] }],
        rooms: [
          { id: "1", buildingId: "b", name: "201호", answers: { light: 2 }, photos: [] },
          { id: "2", buildingId: "b", name: "301호", answers: { light: 10 }, photos: [] },
          { id: "3", buildingId: "b", name: "401호", answers: {}, photos: [] },
        ],
      }),
    ]);

  it("orders the rooms, and leaves the unfinished one last and unranked", async () => {
    const user = userEvent.setup();
    show(threeRooms());
    await user.click(huntNamed("가을 이사"));

    const rooms = screen.getAllByRole("listitem").map((item) => item.textContent ?? "");
    expect(rooms[0]).toContain("301호");
    expect(rooms[1]).toContain("201호");
    expect(rooms[2]).toContain("401호");
    expect(rooms[2]).toContain("1개 남았어요");
  });

  it("holds two rooms up against each other, marking the better answer", async () => {
    const user = userEvent.setup();
    show(threeRooms());
    await user.click(huntNamed("가을 이사"));

    await user.click(screen.getByRole("button", { name: "나란히 보기" }));
    await user.click(screen.getByRole("button", { name: /301호/ }));
    await user.click(screen.getByRole("button", { name: /201호/ }));
    await user.click(screen.getByRole("button", { name: "나란히 보기" }));

    const row = screen.getByRole("row", { name: /채광/ });
    expect(within(row).getByText("10점")).toHaveAttribute("data-best", "true");
    expect(within(row).getByText("2점")).toHaveAttribute("data-best", "false");
  });
});

/** The card for one criterion, found by the name it shows. */
function rowOf(name: string): HTMLElement {
  const row = screen.getByText(name).closest("li");
  if (!row) throw new Error(`no row for ${name}`);
  return row;
}
