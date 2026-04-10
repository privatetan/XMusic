import SwiftUI

struct NowPlayingArtworkSection: View {
    let track: Track
    let animation: Namespace.ID
    let compactHeight: Bool
    let sectionHeight: CGFloat
    let topReservedHeight: CGFloat
    let topSectionBottomPadding: CGFloat
    let artworkSize: CGFloat
    let squeezeProgress: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: topReservedHeight)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                ArtworkView(track: track, cornerRadius: 26, iconSize: compactHeight ? 26 : 30)
                    .frame(width: artworkSize, height: artworkSize)
                    .matchedGeometryEffect(id: "Artwork", in: animation)
                    .clipped()
                    .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(1.0 - (squeezeProgress * 0.08))

            Spacer(minLength: topSectionBottomPadding)
        }
        .frame(height: sectionHeight, alignment: .center)
    }
}

struct NowPlayingControlsSection: View {
    @EnvironmentObject private var player: MusicPlayerViewModel

    let track: Track
    let compactHeight: Bool
    let sectionHeight: CGFloat
    let titleSectionSpacing: CGFloat
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
            Spacer(minLength: compactHeight ? 16 : 20)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: compactHeight ? 28 : 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)

                    Text(track.artist)
                        .font(.system(size: compactHeight ? 18 : 20, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .scaleEffect(x: 1.0 - (squeezeProgress * 0.12), y: 1.0)
            }

            Spacer().frame(height: titleSectionSpacing)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: secondaryGap)

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
        .frame(height: sectionHeight, alignment: .top)
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
