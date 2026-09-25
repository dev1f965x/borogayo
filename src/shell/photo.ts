/** Wide enough to recognise a thing in a list, small enough that a hundred of them fit. */
export const WIDEST = 640;

/**
 * Shrinks a photo from the camera on the device, before it is stored (ADR 6).
 *
 * A file that is not an image, or a browser that cannot draw it, returns nothing rather
 * than throwing, since the photo is optional.
 */
export async function shrink(file: Blob, widest = WIDEST): Promise<Blob | undefined> {
  try {
    const picture = await createImageBitmap(file);
    const scale = Math.min(1, widest / Math.max(picture.width, picture.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(picture.width * scale);
    canvas.height = Math.round(picture.height * scale);

    const paper = canvas.getContext("2d");
    if (!paper) return undefined;
    paper.drawImage(picture, 0, 0, canvas.width, canvas.height);
    picture.close();

    return await new Promise((resolve) =>
      canvas.toBlob((blob) => resolve(blob ?? undefined), "image/jpeg", 0.8),
    );
  } catch {
    return undefined;
  }
}
