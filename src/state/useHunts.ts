import { useCallback, useMemo, useState } from "react";
import {
  type Answer,
  type Criterion,
  ORDINARY_WEIGHT,
  STARTING_CRITERIA,
  type Weight,
} from "../domain/criteria";
import type { Building, Hunt, Photo, Room } from "../domain/hunt";
import type { Photos } from "../storage/photos";
import type { Store } from "../storage/store";

/** What was just undone away, kept long enough to put back. */
interface Undoable {
  hunts: Hunt[];
  message: string;
}

export function useHunts(store: Store, photos: Photos, today: string) {
  const [hunts, setHunts] = useState<Hunt[]>(() => store.readHunts());
  const [openId, setOpenId] = useState<string>();
  const [before, setBefore] = useState<Undoable>();

  const keep = useCallback(
    (next: Hunt[]) => {
      setHunts(next);
      store.writeHunts(next);
    },
    [store],
  );

  /** Rewrites one hunt in place, as nearly every change below does. */
  const change = useCallback(
    (id: string, how: (hunt: Hunt) => Hunt) => {
      keep(hunts.map((hunt) => (hunt.id === id ? how(hunt) : hunt)));
    },
    [hunts, keep],
  );

  const undoable = useCallback((message: string) => setBefore({ hunts, message }), [hunts]);

  const open = useMemo(() => hunts.find((hunt) => hunt.id === openId), [hunts, openId]);

  const start = useCallback(
    (name: string) => {
      // The criteria as they were last left, copied with new ids.
      const criteria = (store.readStartingCriteria() ?? STARTING_CRITERIA).map((criterion) => ({
        ...criterion,
        id: crypto.randomUUID(),
      }));
      const hunt: Hunt = {
        id: crypto.randomUUID(),
        name: name.trim(),
        startedOn: today,
        criteria,
        buildings: [],
        rooms: [],
      };
      keep([hunt, ...hunts]);
      setOpenId(hunt.id);
    },
    [hunts, keep, store, today],
  );

  const removeHunt = useCallback(
    (id: string, message: string) => {
      undoable(message);
      const gone = hunts.find((hunt) => hunt.id === id);
      keep(hunts.filter((hunt) => hunt.id !== id));
      if (openId === id) setOpenId(undefined);
      for (const photo of photosOf(gone)) photos.remove(photo.id);
    },
    [hunts, keep, openId, photos, undoable],
  );

  const renameHunt = useCallback(
    (id: string, name: string) => {
      const named = name.trim();
      if (named !== "") change(id, (hunt) => ({ ...hunt, name: named }));
    },
    [change],
  );

  /** The edited set becomes what the next hunt starts from, which is how a person learns. */
  const keepCriteria = useCallback(
    (id: string, criteria: Criterion[]) => {
      change(id, (hunt) => ({ ...hunt, criteria }));
      store.writeStartingCriteria(criteria);
    },
    [change, store],
  );

  const addCriterion = useCallback(
    (id: string, draft: Omit<Criterion, "id" | "weight"> & { weight?: Weight }) => {
      const hunt = hunts.find((each) => each.id === id);
      if (!hunt) return;

      keepCriteria(id, [
        ...hunt.criteria,
        { ...draft, weight: draft.weight ?? ORDINARY_WEIGHT, id: crypto.randomUUID() },
      ]);
    },
    [hunts, keepCriteria],
  );

  const editCriterion = useCallback(
    (id: string, criterionId: string, changes: Partial<Omit<Criterion, "id">>) => {
      const hunt = hunts.find((each) => each.id === id);
      if (!hunt) return;

      keepCriteria(
        id,
        hunt.criteria.map((criterion) =>
          criterion.id === criterionId ? { ...criterion, ...changes } : criterion,
        ),
      );
    },
    [hunts, keepCriteria],
  );

  const moveCriterion = useCallback(
    (id: string, criterionId: string, by: number) => {
      const hunt = hunts.find((each) => each.id === id);
      if (!hunt) return;

      const at = hunt.criteria.findIndex((criterion) => criterion.id === criterionId);
      const to = at + by;
      if (at < 0 || to < 0 || to >= hunt.criteria.length) return;

      const moved = [...hunt.criteria];
      [moved[at], moved[to]] = [moved[to], moved[at]];
      keepCriteria(id, moved);
    },
    [hunts, keepCriteria],
  );

  const removeCriterion = useCallback(
    (id: string, criterionId: string, message: string) => {
      const hunt = hunts.find((each) => each.id === id);
      if (!hunt) return;

      undoable(message);
      keepCriteria(
        id,
        hunt.criteria.filter((criterion) => criterion.id !== criterionId),
      );
    },
    [hunts, keepCriteria, undoable],
  );

  const addBuilding = useCallback(
    (id: string, name: string) => {
      const building: Building = {
        id: crypto.randomUUID(),
        name: name.trim(),
        answers: {},
        photos: [],
      };
      change(id, (hunt) => ({ ...hunt, buildings: [...hunt.buildings, building] }));
      return building.id;
    },
    [change],
  );

  const addRoom = useCallback(
    (id: string, buildingId: string, name: string) => {
      const room: Room = {
        id: crypto.randomUUID(),
        buildingId,
        name: name.trim(),
        answers: {},
        photos: [],
      };
      change(id, (hunt) => ({ ...hunt, rooms: [...hunt.rooms, room] }));
      return room.id;
    },
    [change],
  );

  const editRoom = useCallback(
    (id: string, roomId: string, changes: Partial<Pick<Room, "name" | "memo">>) => {
      change(id, (hunt) => ({
        ...hunt,
        rooms: hunt.rooms.map((room) => (room.id === roomId ? { ...room, ...changes } : room)),
      }));
    },
    [change],
  );

  const removeRoom = useCallback(
    (id: string, roomId: string, message: string) => {
      const hunt = hunts.find((each) => each.id === id);
      const room = hunt?.rooms.find((each) => each.id === roomId);
      if (!hunt || !room) return;

      undoable(message);
      // A building is only there to hold rooms, so it goes with the last of them.
      const left = hunt.rooms.filter((each) => each.id !== roomId);
      const emptied = !left.some((each) => each.buildingId === room.buildingId);
      const building = hunt.buildings.find((each) => each.id === room.buildingId);

      change(id, (each) => ({
        ...each,
        rooms: left,
        buildings: emptied
          ? each.buildings.filter((one) => one.id !== room.buildingId)
          : each.buildings,
      }));

      for (const photo of [...room.photos, ...(emptied ? (building?.photos ?? []) : [])]) {
        photos.remove(photo.id);
      }
    },
    [hunts, change, photos, undoable],
  );

  /** One answer, written where its criterion says it belongs (ADR 7). */
  const answer = useCallback(
    (id: string, roomId: string, criterionId: string, value: Answer | undefined) => {
      const hunt = hunts.find((each) => each.id === id);
      const room = hunt?.rooms.find((each) => each.id === roomId);
      const criterion = hunt?.criteria.find((each) => each.id === criterionId);
      if (!hunt || !room || !criterion) return;

      const written = (answers: Record<string, Answer>) => {
        const next = { ...answers };
        if (value === undefined) delete next[criterionId];
        else next[criterionId] = value;
        return next;
      };

      change(id, (each) =>
        criterion.scope === "building"
          ? {
              ...each,
              buildings: each.buildings.map((building) =>
                building.id === room.buildingId
                  ? { ...building, answers: written(building.answers) }
                  : building,
              ),
            }
          : {
              ...each,
              rooms: each.rooms.map((one) =>
                one.id === roomId ? { ...one, answers: written(one.answers) } : one,
              ),
            },
      );
    },
    [hunts, change],
  );

  const addPhoto = useCallback(
    async (
      id: string,
      owner: { roomId?: string; buildingId?: string },
      area: string,
      file: Blob,
    ) => {
      const photo: Photo = { id: crypto.randomUUID(), area };
      await photos.put(photo.id, file);

      change(id, (hunt) => ({
        ...hunt,
        buildings: hunt.buildings.map((building) =>
          building.id === owner.buildingId
            ? { ...building, photos: [...building.photos, photo] }
            : building,
        ),
        rooms: hunt.rooms.map((room) =>
          room.id === owner.roomId ? { ...room, photos: [...room.photos, photo] } : room,
        ),
      }));
    },
    [change, photos],
  );

  const removePhoto = useCallback(
    (id: string, photoId: string, message: string) => {
      undoable(message);
      const without = (kept: Photo[]) => kept.filter((photo) => photo.id !== photoId);
      change(id, (hunt) => ({
        ...hunt,
        buildings: hunt.buildings.map((building) => ({
          ...building,
          photos: without(building.photos),
        })),
        rooms: hunt.rooms.map((room) => ({ ...room, photos: without(room.photos) })),
      }));
      photos.remove(photoId);
    },
    [change, photos, undoable],
  );

  const undo = useCallback(() => {
    setBefore((last) => {
      if (last) keep(last.hunts);
      return undefined;
    });
  }, [keep]);

  const forgetUndo = useCallback(() => setBefore(undefined), []);

  return {
    hunts,
    open,
    undoing: before?.message,
    openHunt: setOpenId,
    start,
    renameHunt,
    removeHunt,
    addCriterion,
    editCriterion,
    moveCriterion,
    removeCriterion,
    addBuilding,
    addRoom,
    editRoom,
    removeRoom,
    answer,
    addPhoto,
    removePhoto,
    undo,
    forgetUndo,
  };
}

function photosOf(hunt: Hunt | undefined): Photo[] {
  if (!hunt) return [];
  return [
    ...hunt.buildings.flatMap((building) => building.photos),
    ...hunt.rooms.flatMap((room) => room.photos),
  ];
}
