import SwiftUI

#Preview("Play Page Artwork") {
    PlayPageDemoView(isLyricsPresented: false)
}

#Preview("Play Page Lyrics") {
    PlayPageDemoView(isLyricsPresented: true)
}

private struct PlayPageDemoView: View {
    @StateObject private var player = MusicPlayerViewModel()
    @Namespace private var animation
    @State private var isScrubbing = false
    @State private var draftTime: Double = 39
    @State private var isLyricsPresented: Bool
    @State private var isRouteSheetPresented = false
    @State private var routePickerTrigger = 0

    init(isLyricsPresented: Bool) {
        _isLyricsPresented = State(initialValue: isLyricsPresented)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = PlayPagePanelLayout(
                size: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )
            let previewTrack = previewTrack
            let previewLines = previewLyrics
            let activeLineID = previewLines.dropFirst().first?.id

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.67, green: 0.64, blue: 0.64),
                        Color(red: 0.58, green: 0.55, blue: 0.55),
                        Color(red: 0.53, green: 0.50, blue: 0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    PlayPageArtworkSectionView(
                        track: previewTrack,
                        animation: animation,
                        layout: layout,
                        squeezeProgress: 0,
                        lines: previewLines,
                        activeLineID: activeLineID,
                        isLoadingLyrics: false,
                        lyricsErrorMessage: nil,
                        isLyricsPresented: isLyricsPresented,
                        showContent: true,
                        onArtistTap: {},
                        onRetryLyrics: {}
                    )

                    PlayPageControlsSectionView(
                        timeline: player.playbackTimeline,
                        layout: layout,
                        showContent: true,
                        squeezeProgress: 0,
                        isExternalAudioRouteActive: true,
                        isScrubbing: $isScrubbing,
                        draftTime: $draftTime,
                        isLyricsPresented: $isLyricsPresented,
                        isRouteSheetPresented: $isRouteSheetPresented,
                        routePickerTrigger: $routePickerTrigger,
                        onPrevious: {},
                        onTogglePlayback: {},
                        onNext: {},
                        onLyricsTap: {
                            isLyricsPresented.toggle()
                        }
                    )
                    .environmentObject(player)
                }
                .frame(width: layout.contentWidth, height: layout.availableHeight)
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.safeTop)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .task {
            player.play(previewTrack, from: [previewTrack])
            player.seek(to: draftTime)
            player.setVolume(0.82)
        }
    }

    private var previewTrack: Track {
        Track(
            title: "紫光夜 (pporappippam)",
            artist: "宣美",
            album: "1/6",
            blurb: "Preview track",
            genre: "K-Pop",
            duration: 206,
            audioURL: nil,
            artwork: ArtworkPalette(
                colors: [
                    Color(red: 0.96, green: 0.82, blue: 0.93),
                    Color(red: 0.70, green: 0.76, blue: 0.92)
                ],
                glow: Color(red: 0.94, green: 0.74, blue: 0.92),
                symbol: "music.note",
                label: "Preview"
            )
        )
    }

    private var previewLyrics: [ParsedLyricLine] {
        [
            ParsedLyricLine(id: "0", time: 0, text: "Purple night, shining softly", extendedLyrics: []),
            ParsedLyricLine(id: "1", time: 19_000, text: "紫光夜在窗边慢慢落下", extendedLyrics: ["pporappippam, pporappippam"]),
            ParsedLyricLine(id: "2", time: 27_000, text: "我沿着月光走向你", extendedLyrics: []),
            ParsedLyricLine(id: "3", time: 35_000, text: "整座城市都安静下来", extendedLyrics: []),
            ParsedLyricLine(id: "4", time: 43_000, text: "只剩心跳和微弱霓虹", extendedLyrics: [])
        ]
    }
}
