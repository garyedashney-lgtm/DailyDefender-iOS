import SwiftUI
import AVFoundation
import AVKit

struct VictoryVideoModal: View {
    let videoName: String                       // e.g. "youareamazingguy"
    @Binding var isPresented: Bool              // controlled by the caller

    @State private var player: AVPlayer?
    @State private var item: AVPlayerItem?
    @State private var endObserver: Any?
    @State private var statusObs: NSKeyValueObservation?
    @State private var retryTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let p = player {
                PlayerVC(player: p, videoGravity: .resizeAspectFill)
                    .ignoresSafeArea()
                    .onAppear { kickPlayback() }
            }

            // Little close “X” for dev convenience; safe to remove later
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(14)
                    }
                }
                Spacer()
            }
        }
        .onAppear { startVideo() }
        .onDisappear { cleanup() }
    }

    // MARK: - Flow

    private func startVideo() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("❌ MP4 \(videoName).mp4 not found in bundle")
            isPresented = false
            return
        }

        cleanup() // clear any previous

        // Audio session up front
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Audio session error:", error)
        }

        let newItem = AVPlayerItem(url: url)
        newItem.preferredForwardBufferDuration = 0
        let newPlayer = AVPlayer(playerItem: newItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.actionAtItemEnd = .pause
        newPlayer.isMuted = false

        // Auto-close when finished
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newItem,
            queue: .main
        ) { _ in
            self.isPresented = false
        }

        // Remember refs
        item = newItem
        player = newPlayer

        // Safety timeout so we never get stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if self.isPresented {
                print("⏱️ Timeout: dismissing cover")
                self.isPresented = false
            }
        }
    }

    /// Try to play; if the item isn’t ready yet, attach KVO + a short nudge/retry.
    private func kickPlayback() {
        guard let p = player, let it = item else { return }

        // If ready, go immediately
        if it.status == .readyToPlay {
            p.seek(to: .zero)
            p.play()
            return
        }

        // KVO for readiness
        statusObs = it.observe(\.status, options: [.new, .initial]) { _, _ in
            if it.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.statusObs = nil
                    p.seek(to: .zero)
                    p.play()
                }
            }
        }

        // Tiny retry “nudge” loop (~1.4s worst case)
        var attempts = 0
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { t in
            attempts += 1
            if it.status == .readyToPlay {
                p.seek(to: .zero)
                p.play()
                t.invalidate()
                return
            }
            if attempts >= 12 { t.invalidate() }
        }
        RunLoop.main.add(retryTimer!, forMode: .common)
    }

    // MARK: - Cleanup

    private func cleanup() {
        retryTimer?.invalidate()
        retryTimer = nil

        player?.pause()
        player = nil
        item = nil

        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }
        statusObs = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - AVPlayerViewController wrapper
private struct PlayerVC: UIViewControllerRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.entersFullScreenWhenPlaybackBegins = false
        vc.exitsFullScreenWhenPlaybackEnds = false
        vc.videoGravity = videoGravity
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
        if vc.videoGravity != videoGravity { vc.videoGravity = videoGravity }
    }
}
