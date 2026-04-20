import SwiftUI

struct SheetHeaderIcon: View {
    let systemName: String
    var foregroundOpacity: Double = 0.88

    var body: some View {
        ZStack {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white.opacity(foregroundOpacity))
        }
        .frame(width: 44, height: 44)
        .modifier(SheetHeaderGlassCircle())
        .contentShape(Circle())
    }
}

private struct SheetHeaderGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                // Older iOS versions can occasionally drop taps when the visible chrome
                // is only provided by material/background effects. Keep a nearly
                // transparent fill inside the hit target so the circular button has a
                // concrete tappable surface.
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.001))
                )
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }
}

struct SheetHeaderButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityAddTraits(.isButton)
    }
}

struct SheetHeaderBar<TrailingContent: View>: View {
    let title: String
    let onBack: () -> Void
    let trailingContent: TrailingContent

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailingContent = trailingContent()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    SheetHeaderIcon(systemName: "chevron.left", foregroundOpacity: 0.72)
                }
                .modifier(SheetHeaderButtonChrome())

                Spacer()

                trailingContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 0)
            .padding(.bottom, 24)
            


            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }
}

struct SheetSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))

            TextField("搜索", text: $text)
                .focused(isFocused)
                .foregroundStyle(.white)
                .tint(.white)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(searchFieldBackground())
        .overlay(searchFieldOutline())
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func searchFieldBackground() -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(iOS 26.0, *) {
            shape.fill(Color.white.opacity(0.10))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
        }
    }

    @ViewBuilder
    private func searchFieldOutline() -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
}

struct SheetCenteredMessage: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.45))
    }
}

struct SongsActionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LibrarySongRow: View {
    @Environment(\.appEdgeSwipeInProgress) private var isEdgeSwipeInProgress
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let playlists: [Playlist]
    let onPlay: () -> Void
    let onAddToPlaylist: (Playlist) -> Void
    let onRemove: () -> Void

    @State private var showingRemoveConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    CoverImgView(track: track, cornerRadius: 10, iconSize: 16)
                        .frame(width: 50, height: 50)
                        .overlay(alignment: .bottomTrailing) {
                            if isCurrent {
                                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .padding(3)
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isEdgeSwipeInProgress)

            Menu {
                TrackExportMenuItem(track: track)

                if !playlists.isEmpty {
                    Menu {
                        ForEach(playlists) { playlist in
                            Button {
                                onAddToPlaylist(playlist)
                            } label: {
                                Label(playlist.title, systemImage: "music.note.list")
                            }
                        }
                    } label: {
                        Label("加入歌单", systemImage: "text.badge.plus")
                    }
                }

                Button(role: .destructive) {
                    showingRemoveConfirm = true
                } label: {
                    Label("从资料库移除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 36, height: 44)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .confirmationDialog("从资料库移除《\(track.title)》？", isPresented: $showingRemoveConfirm, titleVisibility: .visible) {
            Button("移除", role: .destructive) { onRemove() }
            Button("取消", role: .cancel) {}
        }
    }
}

struct SheetSongRow: View {
    @Environment(\.appEdgeSwipeInProgress) private var isEdgeSwipeInProgress
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let isInLibrary: Bool
    let customPlaylists: [Playlist]
    let playlistContainsTrack: (Playlist) -> Bool
    let onAddToLibrary: () -> Void
    let onAddToPlaylist: (Playlist) -> Void
    let onRemove: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    CoverImgView(track: track, cornerRadius: 10, iconSize: 16)
                        .frame(width: 50, height: 50)
                        .overlay(alignment: .bottomTrailing) {
                            if isCurrent {
                                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .padding(3)
                            }
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? Color(red: 0.50, green: 0.52, blue: 1.0) : .white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isEdgeSwipeInProgress)

            Menu {
                TrackExportMenuItem(track: track)

                Button(isInLibrary ? "已在资料库" : "加入资料库", systemImage: isInLibrary ? "checkmark" : "square.and.arrow.down") {
                    onAddToLibrary()
                }
                .disabled(isInLibrary)

                if !customPlaylists.isEmpty {
                    Menu {
                        ForEach(customPlaylists) { playlist in
                            if playlistContainsTrack(playlist) {
                                Button("\(playlist.title) 已添加", systemImage: "checkmark") {
                                }
                                .disabled(true)
                            } else {
                                Button(playlist.title, systemImage: "text.badge.plus") {
                                    onAddToPlaylist(playlist)
                                }
                            }
                        }
                    } label: {
                        Label("加入歌单", systemImage: "text.badge.plus")
                    }
                }

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("删除缓存", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 36, height: 44)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct PlaylistSheetRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            PlaylistSheetCoverView(
                playlist: playlist,
                cornerRadius: 10,
                iconSize: 20,
                showsGradientOverlay: false
            )
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(playlist.tracks.count) 首歌曲")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct PlaylistSheetCoverView: View {
    let playlist: Playlist
    let cornerRadius: CGFloat
    let iconSize: CGFloat
    var showsGradientOverlay = true

    var body: some View {
        ZStack {
            coverArtwork

            if showsGradientOverlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var coverArtwork: some View {
        if let customArtworkData = playlist.customArtworkData,
           let uiImage = UIImage(data: customArtworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let remoteArtworkURL = playlist.remoteArtworkURL {
            AsyncImage(url: remoteArtworkURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: playlist.artwork.colors + [Color.black.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: playlist.artwork.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}
