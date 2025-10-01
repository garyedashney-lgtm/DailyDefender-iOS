import SwiftUI
import AVFoundation
import AVKit

/// A dev-only screen wired to your Monthly tab to prove out first-play reliability.
struct DevVideoTestView: View {
    @State private var showVideo = false
    @State private var player: AVPlayer?
    @State private var endObserver: Any?
    @State private var dismissTimer: Timer?

    @State private var preparing = false
    @State private var prepError: String?

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Monthly — Dev Video Test")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    Task { await startVideoFlow() }
                } label: {
                    Text(preparing ? "Preparing…" : "▶︎ Play Victory Video")
                        .font(.headline)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(preparing ? .gray : AppTheme.appGreen)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(preparing)

                if let err = prepError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showVideo, onDismiss: cleanup) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let p = player {
                    PlayerVCHost(player: p, gravity: .resizeAspectFill)   // play starts in viewDidAppear
                        .ignoresSafeArea()
                }
            }
        }
        .onDisappear { cleanup() }
    }

    // MARK: - Flow

    private func cleanup() {
        dismissTimer?.invalidate(); dismissTimer = nil

        player?.pause()
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }
        player = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func scheduleSafetyDismiss() {
        dismissTimer?.invalidate()
        // If we somehow never get video, don’t hang here forever.
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { _ in
            if showVideo { showVideo = false }
        }
        RunLoop.main.add(dismissTimer!, forMode: .common)
    }

    /// 1) Preload asset keys; 2) build player; 3) present; 4) play in viewDidAppear.
    private func startVideoFlow() async {
        guard !preparing else { return }
        preparing = true
        prepError = nil

        // Look up the movie in the bundle
        guard let url = Bundle.main.url(forResource: "youareamazingguy", withExtension: "mp4") else {
            prepError = "❌ MP4 not found in bundle"
            preparing = false
            return
        }

        // Audio session early so we don’t get silent first frames
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Not fatal — proceed
        }

        // PRELOAD the asset before creating the item
        let asset = AVURLAsset(url: url)
        do {
            // ✅ Correct async properties:
            // - isPlayable (Bool)
            // - tracks ([AVAssetTrack])
            // - duration (CMTime)
            let playable = try await asset.load(.isPlayable)
            _ = try await asset.load(.tracks)
            _ = try await asset.load(.duration)

            guard playable else {
                prepError = "Asset isn’t playable."
                preparing = false
                return
            }
        } catch {
            prepError = "Failed to load asset: \(error.localizedDescription)"
            preparing = false
            return
        }

        // Build item / player *after* we know the asset is ready
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 0
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.actionAtItemEnd = .pause
        newPlayer.isMuted = false

        // Auto-close when finished
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            self.showVideo = false
        }

        player = newPlayer

        // Present the cover first; the PlayerVCHost will call play() in viewDidAppear
        showVideo = true
        scheduleSafetyDismiss()

        preparing = false
    }
}

// MARK: - Tiny AVPlayerViewController host that starts in viewDidAppear
private struct PlayerVCHost: UIViewControllerRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIViewController(context: Context) -> InternalPlayerVC {
        let vc = InternalPlayerVC()
        vc.player = player
        vc.gravity = gravity
        return vc
    }

    func updateUIViewController(_ vc: InternalPlayerVC, context: Context) {
        if vc.player !== player { vc.player = player }
        vc.gravity = gravity
        vc.applyGravityIfNeeded()
    }

    final class InternalPlayerVC: AVPlayerViewController {
        var gravity: AVLayerVideoGravity = .resizeAspectFill
        private var didStart = false

        override func viewDidLoad() {
            super.viewDidLoad()
            showsPlaybackControls = false
            entersFullScreenWhenPlaybackBegins = false
            exitsFullScreenWhenPlaybackEnds = false
            videoGravity = gravity
        }

        func applyGravityIfNeeded() {
            if videoGravity != gravity { videoGravity = gravity }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !didStart, let p = player else { return }
            didStart = true

            if let item = p.currentItem, item.status == .readyToPlay {
                p.seek(to: .zero)
                p.play()
            } else {
                // Nudge shortly after appear if status is still updating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    p.seek(to: .zero)
                    p.play()
                }
            }
        }
    }
}
