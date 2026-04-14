import SwiftUI

struct RecentlyAddedCardView: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    CoverImgView(track: track, cornerRadius: 10, iconSize: 18)
                        .frame(width: geo.size.width, height: geo.size.width)
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
