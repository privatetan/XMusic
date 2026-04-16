import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

private struct PlaylistDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CustomPlaylistEditorSession: Identifiable {
    let id = UUID()
    let playlistKey: String?
}

#if canImport(UIKit)
struct PlaylistNavigationBarConfigurator: UIViewControllerRepresentable {
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let shadowColor: UIColor?

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.apply(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            shadowColor: shadowColor
        )
    }

    final class Controller: UIViewController {
        private var backgroundColor: UIColor = UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1)
        private var foregroundColor: UIColor = .white
        private var shadowColor: UIColor?

        override func viewDidLoad() {
            super.viewDidLoad()
            updateAppearance()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            updateAppearance()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateAppearance()
        }

        func apply(backgroundColor: UIColor, foregroundColor: UIColor, shadowColor: UIColor?) {
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.shadowColor = shadowColor
            updateAppearance()
        }

        private func updateAppearance() {
            guard let navigationBar = navigationController?.navigationBar else { return }

            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: foregroundColor]

            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = foregroundColor
            navigationBar.isTranslucent = true
        }
    }
}
#endif

struct PlaylistView: View {
    @EnvironmentObject private var sourceLibrary: MusicSourceLibrary
    @EnvironmentObject private var library: MusicLibraryViewModel
    @EnvironmentObject private var playlistModel: MusicPlaylistViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var playlistEditorSession: CustomPlaylistEditorSession?

    var body: some View {
        AppNavigationContainerView {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        Text("歌单")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        customPlaylistSection

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 12) {
                                SectionHeadingView(title: "在线歌单")

                                Spacer(minLength: 0)
                            }

                            remotePlaylistSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                }
            }
            .appRootNavigationHidden()
        }
        .onAppear {
            syncPlaylists()
        }
        .appOnChange(of: sourceLibrary.activeSourceID) {
            syncPlaylists()
        }
        .appOnChange(of: playlistModel.selectedSource) {
            if !playlistModel.availableSorts.contains(playlistModel.selectedSort),
               let firstSort = playlistModel.availableSorts.first {
                playlistModel.selectedSort = firstSort
            }
            if playlistModel.selectedSource != nil {
                playlistModel.reload()
            }
        }
        .appOnChange(of: playlistModel.selectedSort) {
            if playlistModel.selectedSource != nil {
                playlistModel.reload()
            }
        }
        .sheet(item: $playlistEditorSession) { session in
            PlaylistCustomEditorSheet(
                draft: session.playlistKey.flatMap { key in
                    playlistModel.draftForCustomPlaylist(
                        playlistModel.playlists.first(where: { $0.stableKey == key }),
                        libraryTracks: library.savedTracks
                    )
                } ?? playlistModel.draftForNewCustomPlaylist(libraryTracks: library.savedTracks),
                isEditing: session.playlistKey != nil
            ) { draft in
                playlistModel.saveCustomPlaylist(draft)
            }
        }
    }

    @ViewBuilder
    private func playlistNoticeCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var customPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SectionHeadingView(title: "自定义歌单")

                Spacer(minLength: 0)

                Button {
                    openCustomPlaylistEditor()
                } label: {
                    Label("新建歌单", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if playlistModel.customPlaylists.isEmpty {
                PlaylistCustomEmptyCard {
                    openCustomPlaylistEditor()
                }
            } else {
                HStack(spacing: 10) {
                    PlaylistFilterPill(
                        title: "\(playlistModel.customPlaylists.count) 张已创建",
                        isSelected: true
                    ) {
                    }
                    .allowsHitTesting(false)
                }

                playlistGrid(playlists: playlistModel.customPlaylists)
            }
        }
    }

    @ViewBuilder
    private var remotePlaylistSection: some View {
        if sourceLibrary.activeSource == nil {
            playlistNoticeCard(
                title: "还没有激活音乐源",
                message: "去设置页激活音乐源后再试。"
            )
        } else if playlistModel.supportedSources.isEmpty {
            playlistNoticeCard(
                title: "当前音源不包含在线平台",
                message: "切换支持歌单的平台音源后再试。"
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeadingView(title: "数据来源")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(playlistModel.supportedSources) { source in
                            PlaylistFilterPill(
                                title: source.title,
                                isSelected: playlistModel.selectedSource == source
                            ) {
                                playlistModel.selectedSource = source
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if playlistModel.availableSorts.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(playlistModel.availableSorts) { sort in
                                PlaylistFilterPill(
                                    title: sort.title,
                                    isSelected: playlistModel.selectedSort == sort
                                ) {
                                    playlistModel.selectedSort = sort
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                if let errorMessage = playlistModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 1.00, green: 0.66, blue: 0.38))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if playlistModel.isLoadingList && playlistModel.remotePlaylists.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)

                        Text("正在从 \(playlistModel.selectedSource?.title ?? "当前平台") 加载歌单…")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else if playlistModel.remotePlaylists.isEmpty {
                    playlistNoticeCard(
                        title: "这一页没有在线歌单",
                        message: "切换平台后再试。"
                    )
                } else {
                    playlistGrid(playlists: playlistModel.remotePlaylists)
                }
            }
        }
    }

    private func syncPlaylists() {
        playlistModel.configure(with: sourceLibrary.activeSource)
        if playlistModel.selectedSource != nil {
            playlistModel.reload()
        }
    }

    @ViewBuilder
    private func playlistGrid(playlists: [Playlist]) -> some View {
        LazyVGrid(columns: playlistColumns, spacing: 14) {
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailPage(
                        playlistModel: playlistModel,
                        playlistKey: playlist.stableKey
                    )
                } label: {
                    PlaylistRowCard(
                        playlist: playlist,
                        isSelected: playlistModel.selectedPlaylistKey == playlist.stableKey
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        playlistModel.selectPlaylist(with: playlist.stableKey)
                    }
                )
            }
        }
    }

    private func openCustomPlaylistEditor(_ playlist: Playlist? = nil) {
        playlistEditorSession = CustomPlaylistEditorSession(playlistKey: playlist?.stableKey)
    }

    private var playlistColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 268 : 300), spacing: 14)]
    }
}

private struct PlaylistCustomEmptyCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    Image(systemName: "music.note.list")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 8) {
                    Text("先建一张自己的歌单")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }

            Button(action: action) {
                Label("创建第一张歌单", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PlaylistCustomEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isEditing: Bool
    let onSave: (CustomPlaylistDraft) -> Void
    private let availableTracks: [Track]
    @State private var playlistID: String?
    @State private var title: String
    @State private var coverImageData: Data?
    @State private var selectedTrackKeys: Set<String>
    @State private var isCoverFileImporterPresented = false
    @State private var isPhotoLibraryPresented = false
    @State private var isTrackPickerPresented = false

    init(
        draft: CustomPlaylistDraft,
        isEditing: Bool,
        onSave: @escaping (CustomPlaylistDraft) -> Void
    ) {
        self.isEditing = isEditing
        self.onSave = onSave
        availableTracks = draft.availableTracks
        _playlistID = State(initialValue: draft.playlistID)
        _title = State(initialValue: draft.title)
        _coverImageData = State(initialValue: draft.coverImageData)
        _selectedTrackKeys = State(initialValue: draft.selectedTrackKeys)
    }

    var body: some View {
        AppNavigationContainerView {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        PlaylistEditorSectionCard(
                            title: "歌单信息"
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                playlistCoverPicker

                                editorTextField(
                                    title: "歌单名称",
                                    text: $title,
                                    prompt: "比如：夜骑回家"
                                )

                                addSongsButton
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(isEditing ? "编辑歌单" : "新建歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "创建") {
                        onSave(
                            CustomPlaylistDraft(
                                playlistID: playlistID,
                                title: title,
                                coverImageData: coverImageData,
                                summary: "",
                                description: "",
                                tagsText: "",
                                selectedTrackKeys: selectedTrackKeys,
                                availableTracks: availableTracks
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isCoverFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    coverImageData = PlaylistCoverImageProcessor.makeCoverImageData(from: data)
                }
            case .failure:
                break
            }
        }
        .sheet(isPresented: $isPhotoLibraryPresented) {
            PlaylistImagePicker { image in
                coverImageData = PlaylistCoverImageProcessor.makeCoverImageData(from: image)
            }
        }
        .sheet(isPresented: $isTrackPickerPresented) {
            PlaylistTrackPickerSheet(
                tracks: availableTracks,
                selectedTrackKeys: $selectedTrackKeys
            )
        }
    }

    private var playlistCoverPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("封面")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.68))

            HStack(alignment: .center, spacing: 14) {
                
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    PlaylistCustomCoverPreview(imageData: coverImageData)
                        .frame(width: 92, height: 92)
                    Menu {
                        Button("从图片库选择", systemImage: "photo.on.rectangle") {
                            isPhotoLibraryPresented = true
                        }

                        Button("从文件选择", systemImage: "folder") {
                            isCoverFileImporterPresented = true
                        }

                        if coverImageData != nil {
                            Divider()

                            Button("移除封面", systemImage: "trash", role: .destructive) {
                                coverImageData = nil
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.55), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: 4)
                }


                Spacer()
            }
        }
    }

    private func editorTextField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.68))

            TextField("", text: text, prompt: Text(prompt).foregroundColor(Color.white.opacity(0.28)))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
    }

    private var addSongsButton: some View {
        Button {
            isTrackPickerPresented = true
        } label: {
            HStack(spacing: 12) {
                Label("添加歌曲", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Text(selectedTrackKeys.isEmpty ? "未选择" : "\(selectedTrackKeys.count) 首")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.56))

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistEditorSectionCard<Content: View>: View {
    let title: String
    var subtitle: String = ""
    let content: Content

    init(
        title: String,
        subtitle: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PlaylistCustomCoverPreview: View {
    let imageData: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.04), Color.black.opacity(0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.82))

                    Text("封面")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.48))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct PlaylistTrackPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tracks: [Track]
    @Binding var selectedTrackKeys: Set<String>

    var body: some View {
        AppNavigationContainerView {
            ZStack {
                AppBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if tracks.isEmpty {
                            Text("资料库还没有歌曲。")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(tracks.enumerated()), id: \.element.storageKey) { index, track in
                                    Button {
                                        toggle(track)
                                    } label: {
                                        HStack(spacing: 12) {
                                            CoverImgView(track: track, cornerRadius: 10, iconSize: 16)
                                                .frame(width: 50, height: 50)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(track.title)
                                                    .font(.body)
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)

                                                Text(track.artist)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }

                                            Spacer(minLength: 0)

                                            Image(systemName: selectedTrackKeys.contains(track.storageKey) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(selectedTrackKeys.contains(track.storageKey) ? .white : Color.white.opacity(0.26))
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if index < tracks.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.07))
                                            .padding(.leading, 62)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("添加歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ track: Track) {
        if selectedTrackKeys.contains(track.storageKey) {
            selectedTrackKeys.remove(track.storageKey)
        } else {
            selectedTrackKeys.insert(track.storageKey)
        }
    }
}

#if canImport(UIKit)
private enum PlaylistCoverImageProcessor {
    static func makeCoverImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return makeCoverImageData(from: image)
    }

    static func makeCoverImageData(from image: UIImage) -> Data? {
        image.croppedSquareImage()?.jpegData(compressionQuality: 0.9)
    }
}

private struct PlaylistImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onSelect: (UIImage) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            dismiss()
        }
    }
}

private extension UIImage {
    func croppedSquareImage() -> UIImage? {
        guard let cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let side = min(width, height)
        let x = (width - side) / 2
        let y = (height - side) / 2
        let rect = CGRect(x: x, y: y, width: side, height: side)

        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
#endif

private struct PlaylistDetailHeroCard: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    let resolvePlaybackQueue: @MainActor () async -> [Track]
    private let metricColumns = [GridItem(.adaptive(minimum: 112), spacing: 10)]

    var body: some View {
        let metaLine = [playlist.curator, playlist.updatedLabel.isEmpty ? nil : playlist.updatedLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
        let descriptionText = playlist.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "来自 \(playlist.source?.title ?? "当前平台") 的歌单详情。"
            : playlist.description

        Group {
            if isCompactLayout {
                compactContent(metaLine: metaLine, descriptionText: descriptionText)
            } else {
                regularContent(metaLine: metaLine, descriptionText: descriptionText)
            }
        }
        .padding(isCompactLayout ? 16 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: playlist.artwork.colors.map { $0.opacity(0.92) } + [Color.black.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var artworkSize: CGFloat {
        isCompactLayout ? 132 : 172
    }

    private var compactArtworkSize: CGFloat {
        104
    }

    private var titleFontSize: CGFloat {
        isCompactLayout ? 27 : 32
    }

    @ViewBuilder
    private func regularContent(metaLine: String, descriptionText: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 30, iconSize: 34)
                .frame(width: artworkSize, height: artworkSize)

            VStack(alignment: .leading, spacing: 14) {
                Text(playlist.primaryCategory.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.58))

                Text(playlist.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Text(descriptionText)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    PlaylistMetricPill(title: "曲目", value: "\(playlist.trackCount) 首")
                    if playlist.hasPlayCount {
                        PlaylistMetricPill(title: "播放", value: playlist.playCountText)
                    }
                    PlaylistMetricPill(title: "来源", value: playlist.source?.title ?? "本地")
                    if !playlist.updatedLabel.isEmpty {
                        PlaylistMetricPill(title: "更新", value: playlist.updatedLabel)
                    }
                }

                detailActions(compact: false)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func compactContent(metaLine: String, descriptionText: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PlaylistCoverView(playlist: playlist, cornerRadius: 26, iconSize: 26)
                    .frame(width: compactArtworkSize, height: compactArtworkSize)

                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.source?.title ?? playlist.primaryCategory)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.58))

                    Text(playlist.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
            }

            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.74))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            compactMetrics

            detailActions(compact: true)
        }
    }

    @ViewBuilder
    private var compactMetrics: some View {
        HStack(spacing: 8) {
            CompactPlaylistMetricChip(title: "曲目", value: "\(playlist.trackCount) 首")
            if playlist.hasPlayCount {
                CompactPlaylistMetricChip(title: "播放", value: playlist.playCountText)
            }
            CompactPlaylistMetricChip(title: "来源", value: playlist.source?.title ?? "本地")
        }
    }

    @ViewBuilder
    private func detailActions(compact: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await playPlaylist(shuffled: false)
                }
            } label: {
                Label("播放歌单", systemImage: "play.fill")
                    .font(compact ? .subheadline.weight(.bold) : .headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, compact ? 12 : 10)
                    .background(Color.white, in: Capsule())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await playPlaylist(shuffled: true)
                }
            } label: {
                Label("随机播放", systemImage: "shuffle")
                    .font(compact ? .subheadline.weight(.bold) : .headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, compact ? 12 : 10)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .labelStyle(.titleAndIcon)
    }

    @MainActor
    private func playPlaylist(shuffled: Bool) async {
        let queue = await resolvePlaybackQueue()
        guard !queue.isEmpty else { return }

        let track = shuffled ? (queue.randomElement() ?? queue[0]) : queue[0]
        player.play(track, from: queue)
    }
}

private struct CompactPlaylistMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct PlaylistDetailPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var player: MusicPlayerViewModel
    @EnvironmentObject private var library: MusicLibraryViewModel
    @ObservedObject var playlistModel: MusicPlaylistViewModel
    let playlistKey: String
    @State private var showsNavigationTitle = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var isStartingPlayback = false
    @State private var isCustomPlaylistEditorPresented = false
    @State private var isDeleteConfirmationPresented = false

    private let accentColor = Color(red: 0.89, green: 0.28, blue: 0.32)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        if let playlist = currentPlaylist {
                            VStack(spacing: 26) {
                                PlaylistCoverView(
                                    playlist: playlist,
                                    cornerRadius: 26,
                                    iconSize: 32,
                                    showsGradientOverlay: false
                                )
                                .frame(width: coverSize, height: coverSize)
                                .padding(.top, 10)

                                VStack(spacing: 8) {
                                    Text(playlist.title)
                                        .font(.system(size: 31, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)

                                    Text(playlist.curator)
                                        .font(.title3.weight(.medium))
                                        .foregroundStyle(accentColor)
                                        .lineLimit(1)

                                    Text(subtitleText(for: playlist))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.46))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: 320)

                                HStack(spacing: 12) {
                                    PlaylistDetailActionButton(
                                        title: "播放",
                                        systemImage: "play.fill",
                                        tint: accentColor
                                    ) {
                                        startPlayback(shuffled: false)
                                    }

                                    PlaylistDetailActionButton(
                                        title: "随机",
                                        systemImage: "shuffle",
                                        tint: accentColor
                                    ) {
                                        startPlayback(shuffled: true)
                                    }
                                }
                                .disabled(isStartingPlayback)
                            }
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(
                                            key: PlaylistDetailScrollOffsetKey.self,
                                            value: geometry.frame(in: .named("playlist-detail-scroll")).maxY
                                        )
                                }
                            )

                            if currentTracks.isEmpty, playlistModel.isLoadingDetail {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .tint(accentColor)
                                    Text("正在加载歌单曲目…")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.52))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                            } else if currentTracks.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "music.note.list")
                                        .font(.title2)
                                        .foregroundStyle(Color.white.opacity(0.35))

                                    Text("这张歌单暂时还没有可展示的曲目")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.54))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(currentTracks.enumerated()), id: \.element.id) { index, track in
                                        PlaylistDetailTrackRow(
                                            track: track,
                                            index: index + 1,
                                            tracks: currentTracks,
                                            accentColor: accentColor
                                        )

                                        if index < currentTracks.count - 1 {
                                            Divider()
                                                .padding(.leading, 66)
                                        }
                                    }
                                }
                                .padding(.horizontal, 6)
                            }
                        } else {
                            ProgressView()
                                .tint(accentColor)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, detailBottomScrollInset(in: geometry))
                }
                .coordinateSpace(name: "playlist-detail-scroll")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
            }

            ToolbarItem(placement: .principal) {
                Text(currentPlaylist?.title ?? "")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .opacity(showsNavigationTitle ? 1 : 0)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if !(currentPlaylist?.isCustomPlaylist ?? false) {
                    Button {
                        Task {
                            await playlistModel.ensureDetailLoaded(for: playlistKey)
                        }
                    } label: {
                        detailToolbarIcon("arrow.clockwise")
                    }
                }

                Menu {
                    if let playlist = currentPlaylist, playlist.isCustomPlaylist {
                        Button("编辑歌单", systemImage: "pencil") {
                            isCustomPlaylistEditorPresented = true
                        }

                        Button("删除歌单", systemImage: "trash", role: .destructive) {
                            isDeleteConfirmationPresented = true
                        }

                        Divider()
                    }

                    Button("播放歌单", systemImage: "play.fill") {
                        startPlayback(shuffled: false)
                    }
                    Button("随机播放", systemImage: "shuffle") {
                        startPlayback(shuffled: true)
                    }
                } label: {
                    detailToolbarIcon("ellipsis")
                }
            }
        }
        .task(id: playlistKey) {
            await MainActor.run {
                playlistModel.selectedPlaylistKey = playlistKey
                showsNavigationTitle = false
            }
            await playlistModel.ensureDetailLoaded(for: playlistKey)
        }
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
            isStartingPlayback = false
        }
        .sheet(isPresented: $isCustomPlaylistEditorPresented) {
            PlaylistCustomEditorSheet(
                draft: playlistModel.draftForCustomPlaylist(currentPlaylist, libraryTracks: library.savedTracks),
                isEditing: true
            ) { draft in
                playlistModel.saveCustomPlaylist(draft)
            }
        }
        .alert("删除这张歌单？", isPresented: $isDeleteConfirmationPresented, presenting: currentPlaylist) { playlist in
            Button("删除", role: .destructive) {
                playlistModel.deleteCustomPlaylist(playlist)
                dismiss()
            }
            Button("取消", role: .cancel) {
            }
        } message: { playlist in
            Text("“\(playlist.title)” 会从这台设备里移除，里面的选歌也会一起删除。")
        }
        .onPreferenceChange(PlaylistDetailScrollOffsetKey.self) { value in
            let nextValue = value < 120
            guard nextValue != showsNavigationTitle else { return }

            withAnimation(.easeInOut(duration: 0.18)) {
                showsNavigationTitle = nextValue
            }
        }
        .preferredColorScheme(ColorScheme.dark)
#if canImport(UIKit)
        .background(
            PlaylistNavigationBarConfigurator(
                backgroundColor: UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1),
                foregroundColor: .white,
                shadowColor: .clear
            )
        )
#endif
    }

    private var currentPlaylist: Playlist? {
        playlistModel.playlists.first(where: { $0.stableKey == playlistKey })
    }

    private var currentTracks: [Track] {
        currentPlaylist?.tracks ?? []
    }

    private var coverSize: CGFloat {
        224
    }

    private var bottomChromeHeight: CGFloat {
        let tabBarHeight = ChromeBarMetrics.height(for: horizontalSizeClass)
        let tabBarContainerHeight = tabBarHeight + 18

        guard player.currentTrack != nil else {
            return tabBarContainerHeight
        }

        let miniPlayerHeight = ChromeBarMetrics.height(for: horizontalSizeClass)
        return tabBarContainerHeight + miniPlayerHeight + 12
    }

    private func detailBottomScrollInset(in geometry: GeometryProxy) -> CGFloat {
        let safeBottom = geometry.safeAreaInsets.bottom
        let centerLift = geometry.size.height * 0.28
        return bottomChromeHeight + safeBottom + centerLift
    }

    private func subtitleText(for playlist: Playlist) -> String {
        var parts = [playlist.source?.title ?? playlist.primaryCategory, "\(playlist.trackCount) 首"]
        if playlist.hasPlayCount {
            parts.append("\(playlist.playCountText) 播放")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func detailToolbarIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.72))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.10), in: Circle())
    }

    @MainActor
    private func playPlaylist(shuffled: Bool) async {
        if currentTracks.isEmpty {
            await playlistModel.ensureDetailLoaded(for: playlistKey)
        }

        let tracks = currentTracks
        guard !tracks.isEmpty else { return }

        let track = shuffled ? (tracks.randomElement() ?? tracks[0]) : tracks[0]
        player.play(track, from: tracks)
    }

    private func startPlayback(shuffled: Bool) {
        guard playbackTask == nil else { return }

        isStartingPlayback = true
        playbackTask = Task { @MainActor in
            defer {
                playbackTask = nil
                isStartingPlayback = false
            }
            await playPlaylist(shuffled: shuffled)
        }
    }
}

private struct PlaylistDetailActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistDetailTrackRow: View {
    @EnvironmentObject private var player: MusicPlayerViewModel
    let track: Track
    let index: Int
    let tracks: [Track]
    let accentColor: Color

    var body: some View {
        let isCurrent = player.currentTrack == track

        HStack(spacing: 10) {
            Button {
                player.play(track, from: tracks)
            } label: {
                HStack(spacing: 12) {
                    PlaylistTrackArtwork(track: track)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.52))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 10)

                    Text(index.formatted())
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.26))

                    Image(systemName: isCurrent && player.isPlaying ? "speaker.wave.2.fill" : "play.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isCurrent ? accentColor : Color.white.opacity(0.55))
                        .frame(width: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if canExportTrackFile(track) {
                Menu {
                    TrackExportMenuItem(track: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct PlaylistTrackArtwork: View {
    let track: Track

    var body: some View {
        ZStack {
            if let artworkURL = track.searchSong?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: track.artwork.colors + [Color.black.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: track.artwork.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct PlaylistRowCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let playlist: Playlist
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: horizontalSizeClass == .compact ? 12 : 14) {
            PlaylistCoverView(playlist: playlist, cornerRadius: 26, iconSize: 24)
                .frame(width: coverSize, height: coverSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(sourceText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(horizontalSizeClass == .compact ? 14 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.06))

                if isSelected {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    playlist.artwork.glow.opacity(0.26),
                                    playlist.artwork.colors.first?.opacity(0.18) ?? Color.white.opacity(0.10),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.62),
                                    playlist.artwork.glow.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.08)),
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: isSelected)
    }

    private var coverSize: CGFloat {
        horizontalSizeClass == .compact ? 82 : 98
    }

    private var cardCornerRadius: CGFloat {
        30
    }

    private var sourceText: String {
        playlist.source?.title ?? playlist.primaryCategory
    }
}

private struct PlaylistFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PlaylistMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PlaylistCoverView: View {
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

struct PlaylistView_Preview: View {
    @Namespace private var animation
    @StateObject private var player: MusicPlayerViewModel
    @StateObject private var sourceLibrary = MusicSourceLibrary()
    @StateObject private var musicSearch = MusicSearchViewModel()

    init() {
        let p = MusicPlayerViewModel()
        p.currentTrack = Track(
            title: "Preview Track",
            artist: "XMusic",
            album: "Preview",
            blurb: "用于播放器预览的占位内容。",
            genre: "Preview",
            duration: 240,
            artwork: ArtworkPalette(
                colors: [Color(red: 0.94, green: 0.38, blue: 0.34), Color(red: 0.18, green: 0.22, blue: 0.34)],
                glow: Color(red: 1.00, green: 0.62, blue: 0.50),
                symbol: "music.note",
                label: "Preview"
            )
        )
        p.isNowPlayingPresented = true
        _player = StateObject(wrappedValue: p)
    }

    var body: some View {
        PlayPagePanelView(timeline: player.playbackTimeline, animation: animation) {
        }
        .environmentObject(player)
        .environmentObject(sourceLibrary)
        .environmentObject(musicSearch)
    }
}

#Preview {
    PlaylistView_Preview()
}
