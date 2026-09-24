# 6. Photos now, video later

Status: accepted
Date: 2026-09-25

## Context

The Flutter version took photos and videos, copied them into app storage, and stripped the
recorded location out of the MP4 by rewriting its boxes in place. A walk-through video is
genuinely useful: it is the only thing that brings back a layout.

It is also minutes of footage. One is bigger than every photo of every place combined.

## Options

- **Both, in the browser's storage.** A single video blows past what IndexedDB will hold,
  and the promise that a hundred photos stay within a few megabytes goes with it.
- **Both, with video on Android only through the file system.** Preserves the feature where
  it is used. It needs a native plugin, a copy into app storage, a thumbnail, and the MP4
  box rewriting ported — a body of work with no test path on the web build, for 2.0.0.
- **Photos now, video on its own version.** Less than the old app does, said plainly.

## Decision

Photos in 2.0.0. Video in 2.1.0, on Android only, where the file system makes it honest.

## Consequences

Less than the Flutter version could do, and the roadmap says so rather than leaving it
implied.

Photos get something the old app had to write code for: every one is drawn onto a canvas
and re-encoded as JPEG on the way in, which resizes it and, in doing so, leaves behind
every EXIF field — the GPS position, the camera, the timestamp. Stripping metadata stops
being a routine that can have a bug in it and becomes a property of how the file is made.
