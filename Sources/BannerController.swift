import AppKit
import SwiftUI

@MainActor
final class BannerController {
    static let shared = BannerController()

    private var windows: [NSWindow] = []
    private var queue: [BannerFlight] = []
    private var isPlaying = false

    private init() {}

    func enqueue(_ flight: BannerFlight) {
        queue.append(flight)
        playNextIfIdle()
    }

    private func playNextIfIdle() {
        guard !isPlaying, !queue.isEmpty else { return }
        let flight = queue.removeFirst()
        present(flight)
    }

    private func present(_ flight: BannerFlight) {
        isPlaying = true
        windows.removeAll()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        guard !screens.isEmpty else {
            isPlaying = false
            playNextIfIdle()
            return
        }

        let group = DispatchGroup()
        var finishedCount = 0
        let totalScreens = screens.count

        for screen in screens {
            let frame = screen.frame
            let bannerHeight: CGFloat = 130
            let topInset: CGFloat = 90
            let windowRect = NSRect(
                x: frame.minX,
                y: frame.maxY - topInset - bannerHeight,
                width: frame.width,
                height: bannerHeight
            )

            let window = NSWindow(
                contentRect: windowRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false

            let hosting = NSHostingController(
                rootView: BannerView(
                    flight: flight,
                    screenWidth: frame.width,
                    onFinished: { [weak self] in
                        finishedCount += 1
                        if finishedCount >= totalScreens {
                            self?.cleanupAndAdvance()
                        }
                        group.leave()
                    }
                )
            )
            group.enter()
            window.contentViewController = hosting
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func cleanupAndAdvance() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        isPlaying = false
        playNextIfIdle()
    }
}
