import SwiftUI

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
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                trailingContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

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
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

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
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                TrackExportMenuItem(track: track)

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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.25, blue: 0.40), Color(red: 0.10, green: 0.11, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note.list")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
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
