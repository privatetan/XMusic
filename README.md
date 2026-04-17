# XMusic

XMusic is an iOS music player built with SwiftUI.

It supports custom music-source importing, multi-source search, synced lyrics, playlist browsing, local caching, and custom playlists in a native mobile interface.

## Features

- Built with SwiftUI
- Import music sources from files, pasted scripts, or URLs
- Search songs across supported platforms
- Browse online playlists and create custom playlists
- Display lyrics, artwork, and playback controls
- Cache media locally for replay and export

## Requirements

- Xcode 15+
- iOS 15.1+

## Run

```bash
open XMusic.xcodeproj
```

Then run the `XMusic` scheme in Xcode on a simulator or device.

## Tests

```bash
xcodebuild test \
  -project XMusic.xcodeproj \
  -scheme XMusic \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Acknowledgements

Thanks to [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop) for the inspiration around music-source ecosystems and related ideas.

## License

MIT License. See the [LICENSE](LICENSE) file for details.
