import SwiftUI

#if os(iOS)
import MediaPlayer

struct SystemVolumeBridgeView: UIViewRepresentable {
    @EnvironmentObject private var player: MusicPlayerViewModel

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            attachSlider(from: volumeView)
        }
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        DispatchQueue.main.async {
            attachSlider(from: uiView)
        }
    }

    private func attachSlider(from volumeView: MPVolumeView) {
        guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else { return }
        player.attachSystemVolumeSlider(slider)
    }
}
#endif
