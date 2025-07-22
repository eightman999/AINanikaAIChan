import Darwin
import Foundation

/// Manager for Fake Memory Object (FMO) compatible shared memory.
class SharedFMO {
  /// App Group identifier used for the shared container.
  static let groupID = "group.com.example.sstp"

  /// FMO buffer size defined by the specification (64KB).
  private let FMOSize = 0x10000

  /// Shared memory file name defined by the Sakura Unicode spec.
  private let fileName = "SakuraUnicode"

  /// Named semaphore used for write locking.
  private let mutexName = "/aink_fmo_mutex"

  private var fileDescriptor: Int32 = -1
  private var mappedPointer: UnsafeMutableRawPointer?
  private var updateTimer: Timer?

  private let ghostPath: String
  private let ghostID: String

  init?(ghostPath: String) {
    self.ghostPath = ghostPath
    self.ghostID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
      .padding(toLength: 32, withPad: "0", startingAt: 0)

    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Self.groupID)
    else {
      return nil
    }
    let fileURL = containerURL.appendingPathComponent(fileName)
    fileDescriptor = open(fileURL.path, O_RDWR | O_CREAT, 0o600)
    if fileDescriptor == -1 { return nil }
    if ftruncate(fileDescriptor, off_t(FMOSize)) != 0 {
      close(fileDescriptor)
      return nil
    }
    let ptr = mmap(nil, FMOSize, PROT_READ | PROT_WRITE, MAP_SHARED, fileDescriptor, 0)
    if ptr == MAP_FAILED {
      close(fileDescriptor)
      return nil
    }
    mappedPointer = ptr
    mappedPointer?.storeBytes(of: UInt32(FMOSize).littleEndian, as: UInt32.self)
  }

  deinit { stop() }

  func start(stateProvider: @escaping () -> (Int32, Int32)) {
    updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      let (surface, talk) = stateProvider()
      self.write(surfaceID: surface, talk: talk)
    }
  }

  func stop() {
    updateTimer?.invalidate()
    updateTimer = nil
    if let ptr = mappedPointer {
      munmap(ptr, FMOSize)
      mappedPointer = nil
    }
    if fileDescriptor != -1 {
      close(fileDescriptor)
      fileDescriptor = -1
    }
  }

  private func write(surfaceID: Int32, talk: Int32) {
    let timestamp = UInt64(Date().timeIntervalSince1970)
    let lines = [
      "\(ghostID).path\u{1}\(ghostPath)",
      "\(ghostID).surface\u{1}\(surfaceID)",
      "\(ghostID).talk\u{1}\(talk)",
      "timestamp\u{1}\(timestamp)",
    ]
    writeLines(lines)
  }

  private func writeLines(_ lines: [String]) {
    guard let base = mappedPointer else { return }
    let sem = sem_open(mutexName, O_CREAT, 0o600, 1)
    guard sem != nil else { return }
    defer { sem_close(sem) }
    sem_wait(sem)

    var cursor = base.advanced(by: 4)
    for line in lines {
      var bytes = Array(line.utf8)
      bytes.append(0x0D)
      bytes.append(0x0A)
      bytes.withUnsafeBytes { ptr in
        memcpy(cursor, ptr.baseAddress, ptr.count)
      }
      cursor = cursor.advanced(by: bytes.count)
    }
    cursor.storeBytes(of: UInt8(0), as: UInt8.self)
    msync(base, FMOSize, MS_ASYNC)
    sem_post(sem)
  }
}
