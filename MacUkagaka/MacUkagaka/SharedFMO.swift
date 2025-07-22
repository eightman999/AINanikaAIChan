import Foundation
import Darwin

/// Shared memory manager using mmap for Fake Memory Object (FMO).
class SharedFMO {
    /// App Group identifier used for the shared container.
    static let groupID = "group.com.example.sstp"
    /// Name of the shared binary file.
    private let fileName = "SharedFmo.bin"
    /// File descriptor for the mapped file.
    private var fileDescriptor: Int32 = -1
    /// Pointer to the mapped memory region.
    private var mappedPointer: UnsafeMutablePointer<FMOData>?
    /// Timer for periodic updates.
    private var updateTimer: Timer?

    /// Data layout stored in the shared memory.
    struct FMOData {
        var surfaceID: Int32
        var talkStatus: Int32
    }

    /// Initializes the shared memory mapping under the App Group container.
    init?() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID) else {
            return nil
        }
        let sstpDir = containerURL.appendingPathComponent("sstp", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: sstpDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        let fileURL = sstpDir.appendingPathComponent(fileName)
        fileDescriptor = open(fileURL.path, O_RDWR | O_CREAT, 0o600)
        guard fileDescriptor != -1 else { return nil }
        let size = MemoryLayout<FMOData>.stride
        if ftruncate(fileDescriptor, off_t(size)) != 0 {
            close(fileDescriptor)
            return nil
        }
        let ptr = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fileDescriptor, 0)
        guard ptr != MAP_FAILED else {
            close(fileDescriptor)
            return nil
        }
        mappedPointer = ptr?.bindMemory(to: FMOData.self, capacity: 1)
    }

    deinit {
        stop()
    }

    /// Starts periodic updates with the provided state provider.
    func start(stateProvider: @escaping () -> (Int32, Int32)) {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let (surface, talking) = stateProvider()
            self?.write(surfaceID: surface, talk: talking)
        }
    }

    /// Stops updates and unmaps the memory.
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        if let ptr = mappedPointer {
            munmap(ptr, MemoryLayout<FMOData>.stride)
            mappedPointer = nil
        }
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    /// Writes the latest surface ID and talk status into the shared memory.
    private func write(surfaceID: Int32, talk: Int32) {
        guard let ptr = mappedPointer else { return }
        ptr.pointee.surfaceID = surfaceID
        ptr.pointee.talkStatus = talk
        msync(ptr, MemoryLayout<FMOData>.stride, MS_ASYNC)
    }
}
