import AppKit
import os.log

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let logger = Logger(subsystem: "com.audiomaster.app", category: "UpdateChecker")
    private static let repo = "GabryeleSantoro/AudioMaster"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    private let downloader = UpdateDownloader()
    private var progressIndicator: NSProgressIndicator?

    // Guards against treating a programmatic modal-stop as a user Cancel tap.
    private var downloadCompletedProgrammatically = false
    // Written by handleDownloadState before calling NSApp.stopModal();
    // read by startDownload after runModal() returns.
    private var lastCompletedURL: URL?
    private var lastFailureMessage: String?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(silent: Bool = false) {
        let context: DownloadContext = silent ? .silent : .manual
        Task {
            do {
                let release = try await fetchLatestRelease()
                let latest = release.version

                if UpdateVersion.isNewer(latest, than: currentVersion) {
                    showUpdateAvailable(
                        version: latest,
                        url: release.htmlURL,
                        dmgURL: release.dmgURL,
                        dmgFileName: release.dmgFileName,
                        context: context
                    )
                } else if !silent {
                    showUpToDate()
                }
            } catch {
                logger.error("Update check failed: \(error.localizedDescription)")
                if !silent {
                    showError(error)
                }
            }
        }
    }

    // MARK: - GitHub API

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let html_url: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }

        var version: String {
            tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name
        }

        var htmlURL: URL? { URL(string: html_url) }

        var dmgURL: URL? {
            assets.first(where: { $0.name.hasSuffix(".dmg") })
                .flatMap { URL(string: $0.browser_download_url) }
        }

        var dmgFileName: String? {
            assets.first(where: { $0.name.hasSuffix(".dmg") })?.name
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - Alerts

    private func showUpdateAvailable(version: String, url: URL?, dmgURL: URL?, dmgFileName: String?, context: DownloadContext) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Update Available")
        alert.informativeText = String(
            localized: "AudioMaster \(version) is available. You are currently running \(currentVersion)."
        )
        alert.alertStyle = .informational

        if dmgURL != nil {
            alert.addButton(withTitle: String(localized: "Download"))
        }
        if url != nil {
            alert.addButton(withTitle: String(localized: "View Release"))
        }
        alert.addButton(withTitle: String(localized: "Later"))

        let response = alert.runModal()

        if dmgURL != nil, response == .alertFirstButtonReturn {
            let fileName = dmgFileName ?? "AudioMaster.dmg"
            startDownload(url: dmgURL!, fileName: fileName, context: context)
        } else if url != nil {
            let viewIndex: NSApplication.ModalResponse = dmgURL != nil ? .alertSecondButtonReturn : .alertFirstButtonReturn
            if response == viewIndex {
                NSWorkspace.shared.open(url!)
            }
        }
    }

    /// Shows a determinate progress alert while downloading.
    ///
    /// Design note: `runModal` runs a nested event loop so Swift Concurrency
    /// `@MainActor` tasks (the downloader's state callbacks) are dispatched and
    /// executed inside that loop. When a terminal state arrives,
    /// `handleDownloadState` calls `NSApp.stopModal()` to break out of `runModal`.
    /// A flag prevents misidentifying the programmatic stop as a user Cancel tap.
    private func startDownload(url: URL, fileName: String, context: DownloadContext) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Downloading Update")
        alert.informativeText = String(localized: "Downloading \(fileName)…")

        let indicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 260, height: 16))
        indicator.isIndeterminate = false
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.doubleValue = 0
        alert.accessoryView = indicator
        alert.addButton(withTitle: String(localized: "Cancel"))

        progressIndicator = indicator
        downloadCompletedProgrammatically = false
        lastCompletedURL = nil
        lastFailureMessage = nil

        downloader.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleDownloadState(state)
            }
        }
        downloader.start(url: url, suggestedFileName: fileName)

        let response = alert.runModal()

        // User-initiated cancel: the flag is still false because handleDownloadState
        // was not the one that ended the modal.
        if !downloadCompletedProgrammatically, response == .alertFirstButtonReturn {
            downloader.cancel()
        }

        // Discard any late state callbacks that arrive after the modal closed.
        downloader.onStateChange = nil

        let completedURL = lastCompletedURL
        let failureMessage = lastFailureMessage
        lastCompletedURL = nil
        lastFailureMessage = nil
        progressIndicator = nil

        if let localURL = completedURL {
            if UpdateScheduler.shouldOpenDMGImmediately(context: context) {
                NSWorkspace.shared.open(localURL)
            } else {
                showUpdateReady(dmgURL: localURL)
            }
        } else if let msg = failureMessage {
            showDownloadError(msg)
        }
        // Cancelled: silent no-op.
    }

    private func handleDownloadState(_ state: UpdateDownloader.State) {
        switch state {
        case .downloading(let progress):
            progressIndicator?.doubleValue = progress
        case .completed(let localURL):
            downloadCompletedProgrammatically = true
            lastCompletedURL = localURL
            NSApp.stopModal()
        case .failed(let message):
            downloadCompletedProgrammatically = true
            lastFailureMessage = message
            NSApp.stopModal()
        case .cancelled:
            downloadCompletedProgrammatically = true
            NSApp.stopModal()
        case .idle:
            break
        }
    }

    private func showUpdateReady(dmgURL: URL) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Update Ready")
        alert.informativeText = String(localized: "The update has been downloaded. Open the disk image to install.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Open DMG"))
        alert.addButton(withTitle: String(localized: "Later"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(dmgURL)
        }
    }

    private func showDownloadError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Download Failed")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = String(localized: "You're Up to Date")
        alert.informativeText = String(
            localized: "AudioMaster \(currentVersion) is the latest version."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Update Check Failed")
        alert.informativeText = String(
            localized: "Could not check for updates. Please check your internet connection and try again."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
