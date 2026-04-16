import SwiftUI

struct PlayPageControlsSectionView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @ObservedObject var timeline: PlaybackTimeline

    let layout: PlayPagePanelLayout
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
                PlayPageSliderBarView(
                    value: Binding(
                        get: { isScrubbing ? draftTime : timeline.currentTime },
                        set: { draftTime = $0 }
                    ),
                    range: 0...max(timeline.duration, 1),
                    activeColor: Color.white.opacity(0.94),
                    trackColor: Color.white.opacity(0.22),
                    height: 8
                ) { editing in
                    isScrubbing = editing
                    if editing {
                        draftTime = timeline.currentTime
                    } else {
                        player.seek(to: draftTime)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 10)

                HStack {
                    Text(format(time: isScrubbing ? draftTime : timeline.currentTime))
                    Spacer()
                    Text("-\(format(time: max(timeline.duration - (isScrubbing ? draftTime : timeline.currentTime), 0)))")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)

                Spacer().frame(height: layout.controlsGap)

                HStack {
                    Spacer()
                    playbackControlButton(systemName: "backward.fill", size: layout.compactHeight ? 28 : 32, touchSize: 40, action: onPrevious)
                    Spacer()
                    playbackControlButton(systemName: player.isPlaying ? "pause.fill" : "play.fill", size: layout.compactHeight ? 30 : 48, touchSize: 40, action: onTogglePlayback)
                    Spacer()
                    playbackControlButton(systemName: "forward.fill", size: layout.compactHeight ? 28 : 32, touchSize: 40, action: onNext)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 24)

                Spacer().frame(height: layout.bottomGap+10)

                HStack(spacing: 16) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.82))

                    PlayPageSliderBarView(
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

                Spacer().frame(height: layout.bottomGap)

                HStack {
                    Spacer()
                    bottomActionButton(systemName: "quote.bubble", size: layout.actionIconSize, isActive: isLyricsPresented, action: onLyricsTap)
                    Spacer()
                    airPlayRouteButton(size: layout.actionIconSize)
                    Spacer()
                    bottomActionButton(systemName: "list.bullet", size: layout.actionIconSize) {}
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, max(layout.safeBottom + (layout.compactHeight ? 4 : 6), 10))

            Spacer(minLength: layout.compactHeight ? 12 : 16)
        }
        .frame(height: layout.bottomSectionHeight, alignment: .top)
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
                .background(Circle().fill(Color.white.opacity(isActive ? 0.14 : 0.001)))
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
