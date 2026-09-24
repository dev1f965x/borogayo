const DATABASE = "borogayo";
const SHELF = "photos";

/**
 * The pictures, which are the only thing here too big for localStorage (ADR 5). Every call
 * is a promise, and the database is only opened once a picture is actually wanted, so a
 * hunt without photos never touches it.
 */
export interface Photos {
  put(id: string, photo: Blob): Promise<void>;
  get(id: string): Promise<Blob | undefined>;
  remove(id: string): Promise<void>;
}

export const localPhotos: Photos = {
  put: (id, photo) => inShelf("readwrite", (shelf) => shelf.put(photo, id)).then(() => undefined),
  get: (id) => inShelf("readonly", (shelf) => shelf.get(id)).then(asBlob),
  remove: (id) => inShelf("readwrite", (shelf) => shelf.delete(id)).then(() => undefined),
};

let opening: Promise<IDBDatabase> | undefined;

function open(): Promise<IDBDatabase> {
  opening ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(SHELF);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return opening;
}

async function inShelf<T>(
  mode: IDBTransactionMode,
  ask: (shelf: IDBObjectStore) => IDBRequest<T>,
): Promise<T | undefined> {
  try {
    const database = await open();
    return await new Promise<T>((resolve, reject) => {
      const request = ask(database.transaction(SHELF, mode).objectStore(SHELF));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  } catch {
    // A picture is the one part of a place that can be missing without breaking anything.
    return undefined;
  }
}

function asBlob(value: unknown): Blob | undefined {
  return value instanceof Blob ? value : undefined;
}
