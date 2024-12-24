/*
 * Copyright 2024 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Common
import Foundation

/// `ByteBuffer` is the interface that stores the data for a `Flatbuffers` object
/// it allows users to write and read data directly from memory thus the use of its
/// functions should be used
@frozen
public struct ByteBuffer {

  /// Storage is a container that would hold the memory pointer to solve the issue of
  /// deallocating the memory that was held by (memory: UnsafeMutableRawPointer)
  @usableFromInline
  final class Storage {
    // This storage doesn't own the memory, therefore, we won't deallocate on deinit.
    private let unowned: Bool
    /// pointer to the start of the buffer object in memory
    var memory: UnsafeMutableRawPointer
    /// Capacity of UInt8 the buffer can hold
    var capacity: Int

    @usableFromInline
    init(count: Int, alignment: Int) {
      memory = UnsafeMutableRawPointer.allocate(
        byteCount: count,
        alignment: alignment)
      capacity = count
      unowned = false
    }

    @usableFromInline
    init(memory: UnsafeMutableRawPointer, capacity: Int, unowned: Bool) {
      self.memory = memory
      self.capacity = capacity
      self.unowned = unowned
    }

    deinit {
      if !unowned {
        memory.deallocate()
      }
    }

    @usableFromInline
    func copy(from ptr: UnsafeRawPointer, count: Int) {
      assert(
        !unowned,
        "copy should NOT be called on a buffer that is built by assumingMemoryBound")
      memory.copyMemory(from: ptr, byteCount: count)
    }

    @usableFromInline
    func initialize(for size: Int) {
      assert(
        !unowned,
        "initalize should NOT be called on a buffer that is built by assumingMemoryBound")
      memset(memory, 0, size)
    }

    /// Reallocates the buffer incase the object to be written doesnt fit in the current buffer
    /// - Parameter size: Size of the current object
    @usableFromInline
    func reallocate(_ size: Int, writerSize: Int, alignment: Int) {
      let currentWritingIndex = capacity &- writerSize
      while capacity <= writerSize &+ size {
        capacity = capacity << 1
      }

      /// solution take from Apple-NIO
      capacity = capacity.convertToPowerofTwo

      let newData = UnsafeMutableRawPointer.allocate(
        byteCount: capacity,
        alignment: alignment)
      memset(newData, 0, capacity &- writerSize)
      memcpy(
        newData.advanced(by: capacity &- writerSize),
        memory.advanced(by: currentWritingIndex),
        writerSize)
      memory.deallocate()
      memory = newData
    }
  }

  @usableFromInline var _storage: Storage
  /// The size of the elements written to the buffer + their paddings
  var writerIndex: Int = 0
  /// Alignment of the current  memory being written to the buffer
  private var alignment = 1
  /// Public Pointer to the buffer object in memory. This should NOT be modified for any reason
  public var memory: UnsafeMutableRawPointer { _storage.memory }
  /// Current capacity for the buffer
  public var capacity: Int { _storage.capacity }

  /// Returns the written bytes into the ``ByteBuffer``
  public var underlyingBytes: [UInt8] {
    let start = memory.bindMemory(to: UInt8.self, capacity: writerIndex)

    let ptr = UnsafeBufferPointer<UInt8>(start: start, count: writerIndex)
    return Array(ptr)
  }

  /// Constructor that creates a Flatbuffer object from a UInt8
  /// - Parameter
  ///   - bytes: Array of UInt8
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  public init(
    bytes: [UInt8],
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    var b = bytes
    _storage = Storage(count: bytes.count, alignment: alignment)
    writerIndex = _storage.capacity
    b.withUnsafeMutableBytes { bufferPointer in
      _storage.copy(from: bufferPointer.baseAddress!, count: bytes.count)
    }
  }

  #if !os(WASI)
  /// Constructor that creates a Flatbuffer from the Swift Data type object
  /// - Parameter
  ///   - data: Swift data Object
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  public init(
    data: Data,
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    var b = data
    _storage = Storage(count: data.count, alignment: alignment)
    writerIndex = _storage.capacity
    b.withUnsafeMutableBytes { bufferPointer in
      _storage.copy(from: bufferPointer.baseAddress!, count: data.count)
    }
  }
  #endif

  /// Constructor that creates a Flatbuffer instance with a size
  /// - Parameter:
  ///   - size: Length of the buffer
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  init(initialSize size: Int) {
    let size = size.convertToPowerofTwo
    _storage = Storage(count: size, alignment: alignment)
    _storage.initialize(for: size)
  }

  #if swift(>=5.0) && !os(WASI)
  /// Constructor that creates a Flatbuffer object from a ContiguousBytes
  /// - Parameters:
  ///   - contiguousBytes: Binary stripe to use as the buffer
  ///   - count: amount of readable bytes
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  public init<Bytes: ContiguousBytes>(
    contiguousBytes: Bytes,
    count: Int,
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    _storage = Storage(count: count, alignment: alignment)
    writerIndex = _storage.capacity
    contiguousBytes.withUnsafeBytes { buf in
      _storage.copy(from: buf.baseAddress!, count: buf.count)
    }
  }
  #endif

  /// Constructor that creates a Flatbuffer from unsafe memory region without copying
  /// - Parameter:
  ///   - assumingMemoryBound: The unsafe memory region
  ///   - capacity: The size of the given memory region
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  public init(
    assumingMemoryBound memory: UnsafeMutableRawPointer,
    capacity: Int,
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    _storage = Storage(memory: memory, capacity: capacity, unowned: true)
    writerIndex = capacity
  }

  /// Creates a copy of the buffer that's being built by calling sizedBuffer
  /// - Parameters:
  ///   - memory: Current memory of the buffer
  ///   - count: count of bytes
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  init(
    memory: UnsafeMutableRawPointer,
    count: Int,
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    _storage = Storage(count: count, alignment: alignment)
    _storage.copy(from: memory, count: count)
    writerIndex = _storage.capacity
  }

  /// Creates a copy of the existing flatbuffer, by copying it to a different memory.
  /// - Parameters:
  ///   - memory: Current memory of the buffer
  ///   - count: count of bytes
  ///   - removeBytes: Removes a number of bytes from the current size
  ///   - allowReadingUnalignedBuffers: allow reading from unaligned buffer
  init(
    memory: UnsafeMutableRawPointer,
    count: Int,
    removing removeBytes: Int,
    allowReadingUnalignedBuffers allowUnalignedBuffers: Bool = false)
  {
    _storage = Storage(count: count, alignment: alignment)
    _storage.copy(from: memory, count: count)
    writerIndex = removeBytes

  }

  /// Clears the current instance of the buffer, replacing it with new memory
  @inline(__always)
  mutating public func clear() {
    writerIndex = 0
    alignment = 1
    _storage.initialize(for: _storage.capacity)
  }

  /// Fills the buffer with padding by adding to the writersize
  /// - Parameter padding: Amount of padding between two to be serialized objects
  @inline(__always)
  @usableFromInline
  mutating func fill(padding: Int) {
    assert(padding >= 0, "Fill should be larger than or equal to zero")
    ensureSpace(size: padding)
    writerIndex = writerIndex &+ (MemoryLayout<UInt8>.size &* padding)
  }

  /// Makes sure that buffer has enouch space for each of the objects that will be written into it
  /// - Parameter size: size of object
  @discardableResult
  @usableFromInline
  @inline(__always)
  mutating func ensureSpace(size: Int) -> Int {
    if size &+ writerIndex > _storage.capacity {
      _storage.reallocate(size, writerSize: writerIndex, alignment: alignment)
    }
    #warning("Check if needed")
//    assert(size < FlatBufferMaxSize, "Buffer can't grow beyond 2 Gigabytes")
    return size
  }

  mutating func writeBytes(_ ptr: UnsafeRawPointer, len: Int) {
    memcpy(
      _storage.memory.advanced(by: writerIndex),
      ptr,
      len)
    writerIndex = writerIndex &+ len
  }
}

extension ByteBuffer: CustomDebugStringConvertible {

  public var debugDescription: String {
    """
    buffer located at: \(_storage.memory), with capacity of \(_storage.capacity)
    { writerIndex: \(writerIndex) }
    """
  }
}
