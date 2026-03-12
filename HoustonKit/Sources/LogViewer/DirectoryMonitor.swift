import Foundation

public final class DirectoryMonitor: Sendable {
    public typealias ChangeHandler = @Sendable () -> Void

    private let url: URL
    nonisolated(unsafe) private var source: DispatchSourceFileSystemObject?
    nonisolated(unsafe) private var fileDescriptor: Int32 = -1

    public init(url: URL) {
        self.url = url
    }

    public func start(onChange: @escaping ChangeHandler) {
        stop()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        dispatchSource.setEventHandler {
            onChange()
        }

        dispatchSource.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source = dispatchSource
        dispatchSource.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
