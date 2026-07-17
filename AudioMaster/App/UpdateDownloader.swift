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
    private var partialDestinationURL: URL?

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
        guard let partialDestinationURL else { return }
        try? FileManager.default.removeItem(at: partialDestinationURL)
        self.partialDestinationURL = nil
    }

    private func cleanupAfterDownload() {
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
        Task { @MainActor in
            let downloadsDirectory = FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first!
            let destination = Self.uniqueDestinationURL(
                in: downloadsDirectory,
                preferredName: self.suggestedFileName
            )
            self.partialDestinationURL = destination

            do {
                try FileManager.default.moveItem(at: location, to: destination)
                self.partialDestinationURL = nil
                self.publish(.completed(destination))
            } catch {
                self.deletePartialDestinationIfNeeded()
                self.publish(.failed(error.localizedDescription))
            }
            self.cleanupAfterDownload()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor in
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }
            self.deletePartialDestinationIfNeeded()
            self.publish(.failed(error.localizedDescription))
            self.cleanupAfterDownload()
        }
    }
}
