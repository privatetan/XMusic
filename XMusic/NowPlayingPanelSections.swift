import SwiftUI

struct NowPlayingArtworkSection: View {
    let track: Track
    let animation: Namespace.ID
    let compactHeight: Bool
    let topSectionHeight: CGFloat
    let topReservedHeight: CGFloat
    let topSectionBottomPadding: CGFloat
    let artworkSize: CGFloat
    let squeezeProgress: CGFloat
    let lines: [ParsedLyricLine]
    let activeLineID: String?
    let isLoadingLyrics: Bool
    let lyricsErrorMessage: String?
    let isLyricsPresented: Bool
    let showContent: Bool
    let onArtistTap: () -> Void
    let onRetryLyrics: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: topReservedHeight)

            heroContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)
            .padding(.horizontal, compactHeight ? 2 : 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .scaleEffect(1.0 - (squeezeProgress * 0.05))

            Spacer(minLength: topSectionBottomPadding)
        }
        .frame(height: topSectionHeight, alignment: .top)
    }

    @ViewBuilder
    private var heroContent: some View {
        if !isLyricsPresented {
            artworkHeroContent
        } else {
            lyricsHeroContent
        }
    }

    //播放页封面+ 歌名 + 歌手名
    @ViewBuilder
    private var artworkHeroContent: some View {
        //Spacer(minLength: compactHeight ? 10 : 14)
        VStack(spacing: compactHeight ? 18 : 22) {
            ArtworkView(track: track, cornerRadius: 28, iconSize: compactHeight ? 28 : 32)
                .frame(width: artworkSize, height: artworkSize)
                .clipped()
                .matchedGeometryEffect(id: "Artwork", in: animation)
                .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        Spacer(minLength: compactHeight ? 10 : 14)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(track.title)
                .font(.system(size: compactHeight ? 28 : 32, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)

            Button(action: onArtistTap) {
                HStack(spacing: 6) {
                    Text(track.artist)
                        .lineLimit(1)
                }
                .font(.system(size: compactHeight ? 18 : 20, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.88))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索歌手 \(track.artist)")
            .accessibilityHint("跳转到搜索结果页")
        }
        .frame(width: artworkSize, alignment: .leading)
    }

    //歌词展示
    @ViewBuilder
    private var lyricsHeroContent: some View {
        if isLoadingLyrics {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView()
                    .tint(.white.opacity(0.84))

                Text("正在加载歌词…")
                    .font(.system(size: compactHeight ? 16 : 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let lyricsErrorMessage {
            VStack(alignment: .leading, spacing: 14) {
                Text(lyricsErrorMessage)
                    .font(.system(size: compactHeight ? 16 : 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.leading)

                Button(action: onRetryLyrics) {
                    Label("重新加载歌词", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !lines.isEmpty {
            HeroLyricsPreview(
                track: track,
                lines: lines,
                activeLineID: activeLineID,
                compactHeight: compactHeight
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("当前歌曲暂无可显示的歌词")
                    .font(.system(size: compactHeight ? 18 : 20, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))

                Text("播放页上半部分会优先展示同步歌词。")
                    .font(.system(size: compactHeight ? 14 : 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct NowPlayingControlsSection: View {
    @EnvironmentObject private var player: MusicPlayerViewModel

    let compactHeight: Bool
    let bottomSectionHeight: CGFloat
    let secondaryGap: CGFloat
    let controlsGap: CGFloat
    let volumeGap: CGFloat
    let bottomGap: CGFloat
    let actionIconSize: CGFloat
    let safeBottom: CGFloat
    let showContent: Bool
    let squeezeProgress: CGFloat
    let isExternalAudioRouteActive: Bool
    @Binding var isScrubbing: Bool
    @Binding var draftTime: Double
    @Binding var isLyricsPresented: Bool
    @Binding var isRouteSheetPresented: Bool
    @Binding var routePickerTrigger: Int
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onLyricsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
         
            VStack(alignment: .leading, spacing: 0) {
               // Spacer().frame(height: secondaryGap)

                NowPlayingSliderBar(
                    value: Binding(
                        get: { isScrubbing ? draftTime : player.currentTime },
                        set: { draftTime = $0 }
                    ),
                    range: 0...max(player.duration, 1),
                    activeColor: Color.white.opacity(0.94),
                    trackColor: Color.white.opacity(0.22),
                    height: 8
                ) { editing in
                    isScrubbing = editing
                    if editing {
                        draftTime = player.currentTime
                    } else {
                        player.seek(to: draftTime)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 10)

                HStack {
                    Text(format(time: isScrubbing ? draftTime : player.currentTime))
                    Spacer()
                    Text("-\(format(time: max(player.duration - (isScrubbing ? draftTime : player.currentTime), 0)))")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)

                Spacer().frame(height: controlsGap)

                HStack {
                    Spacer()

                    playbackControlButton(systemName: "backward.fill", size: compactHeight ? 28 : 32, touchSize: 40, action: onPrevious)

                    Spacer()

                    playbackControlButton(systemName: player.isPlaying ? "pause.fill" : "play.fill", size: compactHeight ? 30 : 48, touchSize: 40, action: onTogglePlayback)

                    Spacer()

                    playbackControlButton(systemName: "forward.fill", size: compactHeight ? 28 : 32, touchSize: 40, action: onNext)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 24)

                Spacer().frame(height: volumeGap)

                HStack(spacing: 16) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.82))

                    NowPlayingSliderBar(
                        value: Binding(
                            get: { player.volume },
                            set: { player.setVolume($0) }
                        ),
                        range: 0...1,
                        activeColor: Color.white.opacity(0.92),
                        trackColor: Color.white.opacity(0.24),
                        height: 8
                    )
                    .frame(height: 6)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .background(SystemVolumeBridgeView().environmentObject(player))
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 25)

                Spacer().frame(height: bottomGap)

                HStack {
                    Spacer()

                    bottomActionButton(
                        systemName: "quote.bubble",
                        size: actionIconSize,
                        isActive: isLyricsPresented,
                        action: onLyricsTap
                    )

                    Spacer()

                    airPlayRouteButton(size: actionIconSize)

                    Spacer()

                    bottomActionButton(systemName: "list.bullet", size: actionIconSize) {
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, max(safeBottom + (compactHeight ? 4 : 6), 10))

            Spacer(minLength: compactHeight ? 12 : 16)
        }
        .frame(height: bottomSectionHeight, alignment: .top)
    }

    @ViewBuilder
    private func playbackControlButton(systemName: String, size: CGFloat, touchSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: touchSize, height: touchSize)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bottomActionButton(
        systemName: String,
        size: CGFloat,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Color.white.opacity(isActive ? 0.96 : 0.74))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.14 : 0.001))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func airPlayRouteButton(size: CGFloat) -> some View {
        #if os(iOS)
        Button {
            #if targetEnvironment(simulator)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isRouteSheetPresented = true
            }
            #else
            routePickerTrigger += 1
            #endif
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isExternalAudioRouteActive ? 0.14 : 0.001))

                Image(systemName: "airplayaudio")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(Color.white.opacity(isExternalAudioRouteActive ? 0.96 : 0.74))
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .background {
            SystemRoutePickerView(trigger: routePickerTrigger)
                .frame(width: 44, height: 44)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("音频输出")
        .accessibilityHint("切换 AirPlay、蓝牙耳机或扬声器")
        #else
        bottomActionButton(systemName: "airplayaudio", size: size) {}
        #endif
    }

    private func format(time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }

        let whole = max(Int(time.rounded(.down)), 0)
        let minutes = whole / 60
        let seconds = whole % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

#Preview("Now Playing Artwork") {
    NowPlayingPanelSectionsPreview(isLyricsPresented: false)
}

#Preview("Now Playing Lyrics") {
    NowPlayingPanelSectionsPreview(isLyricsPresented: true)
}

private struct NowPlayingPanelSectionsPreview: View {
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
        let compactHeight = false
        let availableHeight: CGFloat = 844
        let topSectionHeight = availableHeight * 0.6
        let bottomSectionHeight = availableHeight * 0.4
        let topReservedHeight: CGFloat = 86
        let artworkSize: CGFloat = 320
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
                NowPlayingArtworkSection(
                    track: previewTrack,
                    animation: animation,
                    compactHeight: compactHeight,
                    topSectionHeight: topSectionHeight,
                    topReservedHeight: topReservedHeight,
                    topSectionBottomPadding: 24,
                    artworkSize: artworkSize,
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

                NowPlayingControlsSection(
                    compactHeight: compactHeight,
                    bottomSectionHeight: bottomSectionHeight,
                    secondaryGap: 10,
                    controlsGap: 28,
                    volumeGap: 34,
                    bottomGap: 16,
                    actionIconSize: 24,
                    safeBottom: 34,
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
            .frame(width: 390, height: availableHeight)
            .padding(.horizontal, 28)
            .padding(.top, 16)
        }
        .frame(width: 430, height: 900)
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
