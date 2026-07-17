import AppKit
import os.log

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let logger = Logger(subsystem: "com.audiomaster.app", category: "UpdateChecker")
    private static let repo = "GabryeleSantoro/AudioMaster"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(silent: Bool = false) {
        Task {
            do {
                let release = try await fetchLatestRelease()
                let latest = release.version

                if isNewer(latest, than: currentVersion) {
                    showUpdateAvailable(version: latest, url: release.htmlURL, dmgURL: release.dmgURL)
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

    // MARK: - Version comparison

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = parseVersion(remote)
        let l = parseVersion(local)

        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    private func parseVersion(_ string: String) -> [Int] {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
        let base = cleaned.split(separator: "-").first ?? Substring(cleaned)
        return base.split(separator: ".").compactMap { Int($0) }
    }

    // MARK: - Alerts

    private func showUpdateAvailable(version: String, url: URL?, dmgURL: URL?) {
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
            NSWorkspace.shared.open(dmgURL!)
        } else if url != nil {
            let viewIndex: NSApplication.ModalResponse = dmgURL != nil ? .alertSecondButtonReturn : .alertFirstButtonReturn
            if response == viewIndex {
                NSWorkspace.shared.open(url!)
            }
        }
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
