# XMusic

XMusic is an iOS music player built with SwiftUI. It combines a native playback experience with script-based music source importing, cross-platform search, synced lyrics, playlist browsing, offline media caching, and custom library management.

The project is designed as a client-only app with no dedicated backend. Most of the intelligence lives inside the app: JavaScript music-source parsing, runtime capability detection, search/playback resolution, and local persistence for playlists, history, and cached files.

## Highlights

- Native iOS app built with SwiftUI
- Import custom JavaScript music sources from files, pasted scripts, or remote URLs
- Search tracks across supported platforms and resolve playback from the active source
- Browse online playlists and create local custom playlists
- Display synced lyrics and artwork during playback
- Cache media locally for faster replay and offline export/sharing
- Store search history, saved tracks, playback preferences, and source settings on-device
- Includes unit tests for parser behavior, lyric normalization, and model logic

## Tech Stack

- Swift
- SwiftUI
- Combine
- AVFoundation
- JavaScriptCore
- XCTest

## Requirements

- Xcode 15 or newer recommended
- iOS 15.1+
- macOS with the iOS Simulator or a physical iPhone/iPad for running the app

## Project Structure

```text
XMusic/
├── XMusic/                  # App source code
│   ├── Components/          # Models, services, parser, runtime, playback helpers
│   └── Views/               # App screens and reusable UI
├── XMusicTests/             # Unit tests
├── XMusic.xcodeproj/        # Xcode project
├── AppInfo.plist
└── ExportOptions.plist
```

## Main Features

### 1. Script-Based Music Sources

XMusic can import JavaScript music-source scripts and inspect their declared capabilities at runtime. Imported sources are persisted locally, and the user can:

- activate a source
- re-parse a source after updating the script
- remove a source
- import from a local file
- paste raw script content
- import from remote links, including raw GitHub URLs

The parser currently recognizes source capabilities such as:

- supported platforms: `kw`, `kg`, `tx`, `wy`, `mg`, `local`
- supported actions: `musicUrl`, `lyric`, `pic`
- supported audio quality declarations

### 2. Search and Playback Resolution

The search module can query multiple supported platforms and turn results into playable tracks. When playback starts, XMusic resolves the final media URL through the active music source, then hands it to the native player.

Related behaviors already implemented in the app include:

- per-source search tabs
- incremental loading for search results
- search history
- preferred playback quality selection
- optional automatic source fallback

### 3. Library, Playlists, and Browse Experience

The app maintains a lightweight local music library and supports both remote playlists and local custom playlists.

- Save search results into the local library
- Create custom playlists from saved tracks
- Browse remote playlists exposed by supported sources
- View recently added songs and playlists
- Continue listening from the current track and saved library

### 4. Lyrics, Artwork, and Media Cache

XMusic includes playback-side conveniences that make it feel more like a full client rather than a demo shell.

- Synced lyric display
- Artwork loading and normalization
- Local media cache with index management
- Clear cache from settings
- Export cached track files with metadata when possible

### 5. Appearance and Settings

The settings screen includes:

- theme switching
- custom background support
- playback quality preference
- source management
- search history cleanup
- media cache cleanup

## Getting Started

### Open the Project

```bash
open XMusic.xcodeproj
```

### Run in Xcode

1. Open the project in Xcode.
2. Select the `XMusic` scheme.
3. Choose an iPhone simulator or a connected device.
4. Press `Run`.

## How to Use Music Sources

After launching the app:

1. Open the Settings screen.
2. Go to music source management.
3. Import a source by file, pasted script, or URL.
4. Activate the imported source.
5. Use Search or Playlist features backed by the source's declared capabilities.

For best results, imported scripts should include metadata in the leading comment block, for example:

```js
/*
 * @name Example Source
 * @description Example provider
 * @author Your Name
 * @homepage https://example.com
 * @version 1.0.0
 */
```

## Running Tests

You can run tests from Xcode or from the command line:

```bash
xcodebuild test \
  -project XMusic.xcodeproj \
  -scheme XMusic \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Current Focus of the Codebase

This repository is currently centered on:

- improving the music-source runtime and parser compatibility
- refining the SwiftUI playback and playlist experience
- making imported-source workflows easier for end users
- expanding test coverage for parsing and model behavior

## Notes

- The app UI is currently primarily written in Chinese, while this README is in English.
- Persistence is local-first and uses on-device storage such as `UserDefaults` and app support files.
- Build artifacts are present in the repository right now; consider excluding them if you want a cleaner source tree for open-source distribution.

## Acknowledgements

Special thanks to [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop) for its inspiring work around music-source ecosystems and related tooling ideas.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
