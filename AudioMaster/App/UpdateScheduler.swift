import Foundation

enum DownloadContext {
    case manual
    case silent
}

@MainActor
final class UpdateScheduler {
    static let shared = UpdateScheduler()

    nonisolated static let minimumAutomaticCheckInterval: TimeInterval = 24 * 60 * 60
    nonisolated static let eligibilityPollInterval: TimeInterval = 60 * 60

    private var timer: Timer?

    nonisolated static func isEligibleForAutomaticCheck(enabled: Bool, lastCheck: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= minimumAutomaticCheckInterval
    }

    nonisolated static func shouldOpenDMGImmediately(context: DownloadContext) -> Bool {
        context == .manual
    }

    func start() {
        // Full wiring in Task 4 — for now evaluate once and start timer no-op body
        evaluateEligibilityAndCheck()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.eligibilityPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateEligibilityAndCheck()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluateEligibilityAndCheck() {
        let now = Date()
        guard Self.isEligibleForAutomaticCheck(
            enabled: AppPreferences.automaticUpdatesEnabled,
            lastCheck: AppPreferences.lastAutomaticUpdateCheckAt,
            now: now
        ) else { return }

        AppPreferences.lastAutomaticUpdateCheckAt = now
        UpdateChecker.shared.checkForUpdates(silent: true)
    }
}
