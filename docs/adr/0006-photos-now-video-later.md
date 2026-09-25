# 6. Photos now, video later

Status: accepted
Date: 2026-09-25

## Context

The Flutter version took photos and videos, copied them into app storage, and stripped the
recorded location out of the MP4 by rewriting its boxes in place. A walk-through video is
useful: it is the only record that shows a layout.

It is also minutes of footage, and one is larger than every photo of every place together.

## Options

- **Both, in the browser's storage.** A single video exceeds what IndexedDB will hold, and
  the requirement that a hundred photos stay within a few megabytes with it.
- **Both, with video on Android only through the file system.** Keeps the feature where it
  is used, but needs a native plugin, a copy into app storage, a thumbnail and the MP4 box
  rewriting ported, none of which the web build can exercise.
- **Photos now, video in a later version.** Less than the old app does.

## Decision

Photos in 2.0.0. Video in 2.1.0, on Android only, where the file system can hold it.

## Consequences

Less than the Flutter version could do, stated in the roadmap rather than left implied.

Photos gain what the old app needed code for. Each is drawn onto a canvas and re-encoded as
JPEG on the way in, which resizes it and drops every EXIF field with it: the GPS position,
the camera and the timestamp. Removing metadata is a property of how the file is made
rather than a routine that can fail.
