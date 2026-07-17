import Foundation

@MainActor
final class UpdateDownloader: NSObject, URLSessionDownloadDelegate {
    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case completed(URL)
        case failed(String)
        case cancelled
    }

    var onStateChange: ((State) -> Void)?

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var suggestedFileName: String = ""

    // Written on MainActor in start() before task.resume(); read on the delegate queue.
    // Single-download lifecycle (start sets it before resume, delegate reads after resume)
    // makes this safe without a lock.
    private nonisolated(unsafe) var cachedSuggestedFileName: String = ""

    // Written on the delegate queue before the file move; read/cleared on MainActor.
    // Best-effort: allows tearDownActiveDownload to delete the in-progress file even
    // when cancel races with the completion delegate.
    private nonisolated(unsafe) var partialDestinationURL: URL?

    nonisolated static func uniqueDestinationURL(
        in directory: URL,
        preferredName: String,
        fileManager: FileManager = .default
    ) -> URL {
        let preferred = directory.appendingPathComponent(preferredName)
        if !fileManager.fileExists(atPath: preferred.path) {
            return preferred
        }

        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var counter = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    func start(url: URL, suggestedFileName: String) {
        tearDownActiveDownload(publishCancelled: false)
        self.suggestedFileName = suggestedFileName
        // Sync nonisolated copy before task.resume() so the delegate can read it safely.
        self.cachedSuggestedFileName = suggestedFileName

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        publish(.downloading(progress: 0))
        task.resume()
    }

    func cancel() {
        tearDownActiveDownload(publishCancelled: true)
    }

    private func tearDownActiveDownload(publishCancelled: Bool) {
        downloadTask?.cancel()
        session?.invalidateAndCancel()
        downloadTask = nil
        session = nil
        deletePartialDestinationIfNeeded()
        if publishCancelled {
            publish(.cancelled)
        }
    }

    private func publish(_ state: State) {
        onStateChange?(state)
    }

    private func deletePartialDestinationIfNeeded() {
        guard let url = partialDestinationURL else { return }
        try? FileManager.default.removeItem(at: url)
        partialDestinationURL = nil
    }

    /// Finalises the session only if `downloadSession` is still the active session.
    /// Guards against a stale completion Task invalidating a session created by a subsequent start().
    private func cleanupAfterDownload(ownedBy downloadSession: URLSession) {
        guard session === downloadSession else { return }
        downloadTask = nil
        session?.finishTasksAndInvalidate()
        session = nil
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.publish(.downloading(progress: progress))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // The file at `location` is deleted by URLSession as soon as this method returns,
        // so the move MUST happen synchronously here before we return.
        let downloadsDirectory = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let destination = Self.uniqueDestinationURL(
            in: downloadsDirectory,
            preferredName: cachedSuggestedFileName
        )

        // Record the destination before moving so cancel() can clean up even if it
        // races with the MainActor Task below.
        partialDestinationURL = destination

        let moveResult: Result<URL, Error>
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            moveResult = .success(destination)
        } catch {
            moveResult = .failure(error)
        }

        // Capture session identity now; the MainActor Task uses it to detect whether
        // a new download was started before this closure runs (generation guard).
        let capturedSession = session
        Task { @MainActor in
            let isActiveSession = self.session === capturedSession
            switch moveResult {
            case .success(let dest):
                if isActiveSession {
                    self.partialDestinationURL = nil
                    self.publish(.completed(dest))
                    self.cleanupAfterDownload(ownedBy: capturedSession)
                } else {
                    // A new download started (or cancel was called) while the move was
                    // in progress. The file reached the destination but we should not
                    // surface it; clean it up instead.
                    try? FileManager.default.removeItem(at: dest)
                    self.partialDestinationURL = nil
                }
            case .failure(let error):
                if isActiveSession {
                    self.deletePartialDestinationIfNeeded()
                    self.publish(.failed(error.localizedDescription))
                    self.cleanupAfterDownload(ownedBy: capturedSession)
                } else {
                    self.partialDestinationURL = nil
                }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let capturedSession = session
        Task { @MainActor in
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            guard self.session === capturedSession else { return }
            self.deletePartialDestinationIfNeeded()
            self.publish(.failed(error.localizedDescription))
            self.cleanupAfterDownload(ownedBy: capturedSession)
        }
    }
}
