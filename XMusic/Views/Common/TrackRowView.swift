import SwiftUI

/// 单首歌曲行组件，负责展示状态并触发播放动作。
struct TrackRowView: View {
    @Environment(\.appEdgeSwipeInProgress) private var isEdgeSwipeInProgress
    let track: Track
    let index: Int
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Text(index.formatted())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(width: 22)

                    CoverImgView(track: track, cornerRadius: 18, iconSize: 18)
                        .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title)
                            .font(.headline)
                            .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : .white)
                            .lineLimit(1)

                        Text("\(track.artist) • \(track.album)")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.64))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: isCurrent && isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(isCurrent ? Color(red: 1.00, green: 0.43, blue: 0.42) : Color.white.opacity(0.86))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isEdgeSwipeInProgress)

            if canExportTrackFile(track) {
                Menu {
                    TrackExportMenuItem(track: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(isCurrent ? 0.11 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(isCurrent ? 0.16 : 0.08), lineWidth: 1)
        )
    }
}
