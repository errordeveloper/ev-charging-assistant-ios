import Foundation

public enum FramingError: Error, Equatable {
    case responseTooLarge
}

/// Frames an ELM/STN-style ASCII stream at its '>' prompt. This only frames
/// bytes; it does not decode CAN, invent a PID, or send diagnostic commands.
public struct PromptFramer: Sendable {
    private var pending = Data()
    public let maxResponseBytes: Int

    public init(maxResponseBytes: Int = 8_192) {
        precondition(maxResponseBytes > 0)
        self.maxResponseBytes = maxResponseBytes
    }

    public mutating func append(_ chunk: Data) throws -> [Data] {
        var frames: [Data] = []
        for byte in chunk {
            if byte == 0x3E {
                frames.append(pending)
                pending.removeAll(keepingCapacity: true)
            } else {
                guard pending.count < maxResponseBytes else {
                    pending.removeAll(keepingCapacity: true)
                    throw FramingError.responseTooLarge
                }
                pending.append(byte)
            }
        }
        return frames
    }

    public mutating func reset() {
        pending.removeAll(keepingCapacity: true)
    }
}
