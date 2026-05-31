import SwiftUI
import AVFoundation
import UIKit

/// Plays a bundled MP4 on loop, muted, scaled-to-fit. Falls back to an emoji
/// placeholder if the resource isn't in the bundle yet.
struct LoopingVideoPlayer: View {
    let resourceName: String          // e.g. "palm" or "rain"
    let placeholderEmoji: String      // shown when MP4 missing

    var body: some View {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") {
            VideoLoopView(url: url)
                .accessibilityHidden(true)
        } else {
            Text(placeholderEmoji)
                .font(.system(size: 140))
                .accessibilityHidden(true)
        }
    }
}

private struct VideoLoopView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopPlayerUIView {
        LoopPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopPlayerUIView, context: Context) {
        uiView.update(url: url)
    }

    static func dismantleUIView(_ uiView: LoopPlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }
}

final class LoopPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .clear
        configure(url: url)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resume),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(url: URL) {
        guard url != currentURL else { return }
        configure(url: url)
    }

    func tearDown() {
        queuePlayer?.pause()
        queuePlayer = nil
        looper = nil
        playerLayer.player = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func resume() {
        queuePlayer?.play()
    }

    private func configure(url: URL) {
        currentURL = url
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        queuePlayer = player
        player.play()
    }
}
