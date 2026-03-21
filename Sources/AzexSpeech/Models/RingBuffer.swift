import Foundation

/// Fixed-size ring buffer for audio samples.
/// Keeps the most recent N samples, discarding oldest when full.
struct RingBuffer<T> {
    private var buffer: [T]
    private var writeIndex = 0
    private var count = 0
    private let capacity: Int

    init(capacity: Int) where T == Float {
        self.capacity = capacity
        self.buffer = Array(repeating: 0.0, count: capacity)
    }

    mutating func write(_ samples: [T]) {
        for sample in samples {
            buffer[writeIndex % capacity] = sample
            writeIndex += 1
        }
        count = min(count + samples.count, capacity)
    }

    /// Read all buffered samples in order (oldest first)
    func read() -> [T] {
        guard count > 0 else { return [] }

        if count < capacity {
            return Array(buffer[0..<count])
        }

        let start = writeIndex % capacity
        return Array(buffer[start..<capacity]) + Array(buffer[0..<start])
    }

    mutating func clear() {
        writeIndex = 0
        count = 0
    }
}
