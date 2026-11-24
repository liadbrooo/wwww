# LYRO Cut · 0.2.0

Native, local-first macOS video editor. This is an early development version, not a feature-complete Premiere replacement.

## Features
- Multiple video/title/audio lanes, time ruler, playhead, drag repositioning with snapping.
- Media import, thumbnails, split, duplicate, trim via inspector, ripple delete, undo/redo.
- Transform, opacity, color controls, six looks, motion presets, fades, clip speed, volume.
- Text overlays, 16:9 / 9:16 / 1:1 canvas, 24–60 FPS.
- AVFoundation playback and Core Image compositor shared by MP4 export.
- Local JSON project files and recovery autosave; source media stays in its original location.
- macOS 14+, universal arm64/x86_64 build, ad-hoc signature. No cloud service or subscription.

## Build
On a Mac with Xcode command line tools, run: bash scripts/build.sh
GitHub Actions builds and uploads the ZIP on pushes to the lyro-cut branch. The app is not notarized; macOS may require explicit approval of a trusted local build. No Apple Developer account is needed for ad-hoc builds.

## Limits
This is the first implementation. Preview/export, codecs, performance and interaction need real-device integration validation. AVFoundation-compatible video/audio only; no arbitrary codec support. No editable keyframe curves, masks, advanced effects, proxy workflow, waveform generation, automatic captions, multicam, 4K output, HDR color management or plugin SDK yet. Fade overlays can create crossfades with overlapping video on separate lanes. No independent audio export. Project files reference original media; do not move the sources.

## 0.2.0
Source aspect ratio and frame rate, UHD option, drag media into timeline, same-lane clip swapping, trim handles, seven video effects, basic rectangle/ellipse masks, editable keyframe curves (position, scale, rotation, opacity), custom icon and DMG. Existing projects load with optional defaults. Tracking, automatic captions and audio waveform analysis are not part of this revision.

Waveforms are calculated from decoded audio locally; scene suggestions use sampled frame differences and can miss cuts. UHD resolution and fractional source frame rates are covered by model tests; the end-to-end MP4 test still exports HD.

## 0.3.0
Native vector recreation of the new glass L / timeline identity and redesigned DMG. Export panel (MP4/MOV/ProRes, resolution, FPS, progress and cancellation), stacked effects, editable mask placement and aspect, audio fades, corrected fractional FPS snapping, source format restoration, keyframe-aware transform editing and insertion/swap improvements. Existing projects remain decodable. UHD export is checked with a real exported file in CI. UI interaction and ProRes still need manual testing. No speech recognition or object tracking yet.

## 0.4.0 Studio Foundation
Dynamic video/audio tracks, track locks/mute/visibility, group selection/move/delete/split, markers, workspace switcher and shared .lyrocut JSON schema v1. Cross-platform projects reference local source files; relink by file name. Browser compatibility covers a subset of native effects and media types.\n
## 0.5.0 Professional Editing (first increment)
Frame-based ripple, roll, slip and slide operations with source handle checks and atomic rejection, plus overlapping same-track cross-dissolves with audio fades. Pro Trim menu. Still planned: multicam, nested sequences, proxies, richer transitions, GPU web export and full production validation.

## 0.5.1 Preferences
Native Settings window, persistent local preferences, new-project defaults, source matching, timeline density/visibility, undo depth, preview resolution cap, export defaults and recovery controls. Existing project settings are not overwritten.
