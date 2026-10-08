import AVKit
import PDFKit
import SwiftUI
import WebKit

// MARK: - YouTube (official IFrame player)

/// Plays a YouTube video with YouTube's own embedded player and keeps it in step with the host.
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let state: SatsangState
    let isHost: Bool
    let localMuted: Bool
    /// Host only: report play/pause/seek from the player.
    let report: (_ playing: Bool, _ time: Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(report: report) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "player")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        context.coordinator.web = web
        web.loadHTMLString(Self.html(videoID: videoID, controls: isHost), baseURL: URL(string: "https://shruezee.github.io/"))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.report = report
        context.coordinator.isHost = isHost
        let muted = localMuted || (!isHost && state.mediaMutedForOthers)
        context.coordinator.apply(muted: muted)
        guard !isHost else { return }
        context.coordinator.follow(playing: state.mediaPlaying, time: state.expectedMediaTime())
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "player")
        coordinator.timer?.invalidate()
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var web: WKWebView?
        var report: (Bool, Double) -> Void
        var isHost = false
        var ready = false
        var timer: Timer?
        private var pending: (playing: Bool, time: Double)?
        private var lastMuted: Bool?

        init(report: @escaping (Bool, Double) -> Void) { self.report = report }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
            switch event {
            case "ready":
                ready = true
                if let lastMuted { js(lastMuted ? "player.mute()" : "player.unMute()") }
                if let pending { follow(playing: pending.playing, time: pending.time) }
                // Followers re-check drift every few seconds.
                timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                    guard let self, !self.isHost, let pending = self.pending else { return }
                    self.follow(playing: pending.playing, time: pending.time + 3)
                }
            case "state" where isHost:
                let playing = (body["playing"] as? Bool) ?? false
                let time = (body["time"] as? Double) ?? 0
                report(playing, time)
            default:
                break
            }
        }

        func apply(muted: Bool) {
            guard muted != lastMuted else { return }
            lastMuted = muted
            if ready { js(muted ? "player.mute()" : "player.unMute()") }
        }

        func follow(playing: Bool, time: Double) {
            pending = (playing, time)
            guard ready, let web else { return }
            web.evaluateJavaScript("player.getCurrentTime()") { [weak self] value, _ in
                guard let self else { return }
                let local = (value as? Double) ?? 0
                if SatsangRules.needsSeek(local: local, expected: time) { self.js("player.seekTo(\(time), true)") }
                self.js(playing ? "player.playVideo()" : "player.pauseVideo()")
            }
        }

        private func js(_ script: String) { web?.evaluateJavaScript(script) }
    }

    /// The host gets YouTube's controls; followers see the video without them.
    static func html(videoID: String, controls: Bool) -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:#000;height:100%}#p{position:absolute;inset:0;width:100%;height:100%}</style></head>
        <body><div id="p"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function send(o){window.webkit.messageHandlers.player.postMessage(o)}
        function onYouTubeIframeAPIReady(){
          player=new YT.Player('p',{videoId:'\(videoID)',playerVars:{playsinline:1,controls:\(controls ? 1 : 0),rel:0,
            modestbranding:1,disablekb:\(controls ? 0 : 1),origin:'https://shruezee.github.io'},
            events:{onReady:function(){send({event:'ready'})},
              onStateChange:function(e){var s=e.data;if(s==1||s==2){send({event:'state',playing:s==1,time:player.getCurrentTime()})}}}});
        }
        </script></body></html>
        """
    }
}

// MARK: - Shared video file

/// Plays a shared video file in step with the host. The host has normal controls.
struct SyncedVideoView: View {
    let url: URL
    let state: SatsangState
    let isHost: Bool
    let localMuted: Bool
    let report: (_ playing: Bool, _ time: Double) -> Void

    @State private var player = AVPlayer()
    @State private var observer: Any?
    @State private var lastReported: (Bool, Double)?

    var body: some View {
        VideoPlayer(player: player)
            .allowsHitTesting(isHost)
            .onAppear {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
                applyMute()
                if isHost { watchHostPlayer() } else { follow() }
            }
            .onDisappear {
                player.pause()
                if let observer { player.removeTimeObserver(observer) }
            }
            .onChange(of: state) { _, _ in
                applyMute()
                if !isHost { follow() }
            }
            .onChange(of: localMuted) { _, _ in applyMute() }
            .task(id: isHost) {
                // Followers correct drift every few seconds.
                while !isHost && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    follow()
                }
            }
    }

    private func applyMute() {
        player.isMuted = localMuted || (!isHost && state.mediaMutedForOthers)
    }

    private func follow() {
        let expected = state.expectedMediaTime()
        if SatsangRules.needsSeek(local: player.currentTime().seconds, expected: expected) {
            player.seek(to: CMTime(seconds: expected, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if state.mediaPlaying, player.timeControlStatus != .playing { player.play() }
        if !state.mediaPlaying, player.timeControlStatus == .playing { player.pause() }
    }

    /// The host's own play, pause and scrubbing become the group's state.
    private func watchHostPlayer() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            let playing = player.timeControlStatus == .playing
            let seconds = time.seconds
            if let (wasPlaying, lastTime) = lastReported {
                let expected = wasPlaying ? lastTime + 0.5 : lastTime
                let jumped = abs(seconds - expected) > 1.0
                guard playing != wasPlaying || jumped else {
                    lastReported = (playing, seconds)
                    return
                }
            }
            lastReported = (playing, seconds)
            report(playing, seconds)
        }
    }
}

// MARK: - Shared PDF

/// Shows a shared PDF on the host's page. The host turns pages for everyone.
struct SyncedPDFView: UIViewRepresentable {
    let url: URL
    let page: Int
    let isHost: Bool
    let onHostPageChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onHostPageChange) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.usePageViewController(true)
        view.backgroundColor = .secondarySystemBackground
        context.coordinator.view = view
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged),
                                               name: .PDFViewPageChanged, object: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.onChange = onHostPageChange
        context.coordinator.isHost = isHost
        view.isUserInteractionEnabled = isHost
        if let document = view.document, page < document.pageCount, let target = document.page(at: page),
           view.currentPage != target {
            context.coordinator.applying = true
            view.go(to: target)
            context.coordinator.applying = false
        }
    }

    final class Coordinator: NSObject {
        weak var view: PDFView?
        var onChange: (Int) -> Void
        var isHost = false
        var applying = false
        init(onChange: @escaping (Int) -> Void) { self.onChange = onChange }

        @objc func pageChanged() {
            guard isHost, !applying, let view, let page = view.currentPage, let document = view.document else { return }
            onChange(document.index(for: page))
        }
    }
}
