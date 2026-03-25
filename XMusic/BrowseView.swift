import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var musicSearch: MusicSearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isSourceManagerPresented = false
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "浏览", subtitle: "从分类、专题和编辑推荐里挑一张")

                SourceManagerEntryCard(
                    sourceCount: sourceLibrary.sources.count,
                    activeSourceName: sourceLibrary.activeSource?.name
                ) {
                    isSourceManagerPresented = true
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(DemoLibrary.genres) { genre in
                        GenreTile(genre: genre)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: "编辑推荐", subtitle: "像 Apple Music 一样的卡片式精选")

                    GeometryReader { geometry in
                        let cardWidth = min(max(geometry.size.width * 0.78, 248), 320)
                        let cardHeight = cardWidth * 0.86

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(DemoLibrary.allTracks) { track in
                                    EditorialCard(track: track, width: cardWidth, height: cardHeight)
                                }
                            }
                            .frame(height: cardHeight)
                            .padding(.horizontal, 2)
                        }
                    }
                    .frame(height: horizontalSizeClass == .compact ? 232 : 276)
                }

                TrackStack(
                    title: "今日排行",
                    subtitle: "把适合反复循环的几首放在一起",
                    tracks: DemoLibrary.allTracks.shuffled()
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $isSourceManagerPresented) {
            MusicSourceManagementView()
                .environmentObject(sourceLibrary)
                .environmentObject(musicSearch)
                .environmentObject(player)
        }
    }
}

struct SourceManagerEntryCard: View {
    let sourceCount: Int
    let activeSourceName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.97, green: 0.41, blue: 0.39),
                                Color(red: 0.35, green: 0.12, blue: 0.40),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "waveform.and.magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text("音乐源管理")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(sourceCount == 0 ? "导入并解析 lx 风格自定义源脚本" : "已导入 \(sourceCount) 个音乐源")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.68))

                    if let activeSourceName {
                        Text("当前：\(activeSourceName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.48, green: 0.92, blue: 0.72))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.36))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EditorialCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let track: Track
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Button {
            player.play(track, from: DemoLibrary.allTracks)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                Text(track.genre.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.56))

                Text(track.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(track.blurb)
                    .font(width < 270 ? .subheadline : .body)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(3)

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    ArtworkView(track: track, cornerRadius: 22, iconSize: 22)
                        .frame(width: artworkSize, height: artworkSize)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.artist)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(track.album)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.66))
                    }
                }
            }
            .padding(width < 270 ? 18 : 20)
            .frame(width: width, height: height, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                track.artwork.colors.first?.opacity(0.9) ?? .black,
                                track.artwork.colors.last?.opacity(0.8) ?? .black,
                                Color.black.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var artworkSize: CGFloat {
        min(max(width * 0.26, 66), 80)
    }

    private var titleFontSize: CGFloat {
        min(max(width * 0.097, 24), 28)
    }
}

private struct GenreTile: View {
    let genre: GenreCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: genre.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            Spacer()

            Text(genre.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(genre.subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: genre.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct GenreRow: View {
    let genre: GenreCard

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: genre.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Image(systemName: genre.symbol)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(genre.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(genre.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.64))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.36))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
