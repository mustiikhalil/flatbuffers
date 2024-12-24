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

public struct FlexBuffersWriter {

  var capacity: Int {
    _bb.capacity
  }

  var writerIndex: Int {
    get {
      _bb.writerIndex
    } set {
      _bb.writerIndex = newValue
    }
  }

  private var finished = false
  private var _bb: ByteBuffer
  private var stack: [Value] = []

  public init(initialSize: Int = 1024) {
    _bb = ByteBuffer(initialSize: initialSize)
  }

  /// Returns the written bytes into the ``ByteBuffer``
  ///
  /// Should only be used after ``finish(offset:addPrefix:)`` is called
  public var sizedByteArray: [UInt8] {
    assert(
      finished == true,
      "function finish() should be called before accessing data")
    return _bb.underlyingBytes
  }

  public var sizedByteBuffer: ByteBuffer {
    assert(
      finished == true,
      "function finish() should be called before accessing data")
    return ByteBuffer(
      assumingMemoryBound: _bb.memory.bindMemory(
        to: UInt8.self,
        capacity: _bb.writerIndex),
      capacity: _bb.writerIndex)
  }

  /// Resets the internal state. Automatically called before building a new flexbuffer.
  public mutating func reset() {
    _bb.clear()
    stack.removeAll(keepingCapacity: true)
    finished = false
    #warning("Implement the rest of the function to match the cpp implementation")
    // flags_ remains as-is;
    //    force_min_bit_width_ = BIT_WIDTH_8;
    //    key_pool.clear();
    //    string_pool.clear();
  }

  // MARK: - Vector
  func startVector() -> Int {
    stack.count
  }

  mutating func startVector(key k: String) -> Int {
    key(str: k)
    return stack.count
  }

  mutating func endVector(start: Int) -> UInt64 {

    stack.removeLast(start)
    return UInt64(start)
  }

  // MARK: - Map
  func startMap() -> Int {
    stack.count
  }

  mutating func startMap(key k: String) -> Int {
    key(str: k)
    return stack.count
  }

  mutating func endMap(start: Int) -> UInt64 {
    return UInt64(start)
  }

  // MARK: - Storing root

  public mutating func finish() {
    assert(stack.count == 1)

    // Write root value.
    var byteWidth = align(width: stack[0].elementWidth(
      size: writerIndex,
      index: 0))

    write(any: stack[0], byteWidth: byteWidth)
    var storedType = stack[0].storedPackedType()
    // Write root type.
    _bb.writeBytes(&storedType, len: 1)
    // Write root size. Normally determined by parent, but root has no parent :)
    _bb.writeBytes(&byteWidth, len: 1)

    finished = true
  }

  // MARK: - Writing strings
  @inline(__always)
  public mutating func write(string: String) {
    write(str: string)
  }

  mutating func key(str: String) {

  }

  // MARK: - Private

  // MARK: Writing to buffer

  @inline(__always)
  private mutating func write(any: Value, byteWidth: Int) {
    switch any.type {
    case .null: preconditionFailure("remove me")
    default:
      write(offset: any.sloc, byteWidth: byteWidth)
    }
  }

  @inline(__always)
  private mutating func write(offset: UInt64, byteWidth: Int) {
    var offset = UInt64(writerIndex) &- offset
    assert(byteWidth == 8 || offset < UInt64.one << (byteWidth * 8))
    _bb.writeBytes(&offset, len: byteWidth)
  }

  // MARK: Internal Writing Strings

  /// Adds a string to the buffer using swift.utf8 object
  /// - Parameter str: String that will be added to the buffer
  /// - Parameter len: length of the string
  @inline(__always)
  @usableFromInline
  mutating func write(str: String) {
    let len = str.utf8.count
    if str.utf8
      .withContiguousStorageIfAvailable({ self.push(bytes: $0, len: len) }) !=
      nil
    {
    } else {
      #warning("Write this")
    }
  }

  /// Writes a string to Bytebuffer using UTF8View
  /// - Parameters:
  ///   - bytes: Pointer to the view
  ///   - len: Size of string
  @usableFromInline
  @inline(__always)
  mutating func push(
    bytes: UnsafeBufferPointer<String.UTF8View.Element>,
    len: Int) -> Bool
  {
    storeBlob(pointer: bytes.baseAddress!, len: len, trailing: 1, type: .string)
    return true
  }


  @usableFromInline
  @inline(__always)
  mutating func storeBlob(_ array: [UInt8]) {
    array.withUnsafeBufferPointer {
      #warning("Fix type to use array of blob")
      storeBlob(pointer: $0.baseAddress!, len: array.count, type: .string)
    }
  }

  // MARK: - Storing Blobs

  @discardableResult
  @usableFromInline
  @inline(__always)
  mutating func storeBlob<T>(
    pointer: UnsafePointer<T>,
    len: Int,
    trailing: Int = 0,
    type: FlexBufferType) -> Int
  {
    _bb.ensureSpace(size: len)
    let bitWidth = widthU(UInt64(len))

    let bytes = align(width: bitWidth)

    var len = len
    _bb.writeBytes(&len, len: bytes)
    let sloc = writerIndex

    _bb.writeBytes(pointer, len: len &+ trailing)
    stack.append(Value(sloc: UInt64(sloc), type: type, bitWidth: bitWidth))
    return sloc
  }

  // MARK: Misc functions
  @inline(__always)
  private mutating func align(width: BitWidth) -> Int {
    let bytes = Int(UInt64.one << width.rawValue)
    writerIndex = writerIndex &+ padding(bufSize: capacity, elementSize: bytes)
    return bytes
  }
}

// MARK: - Vectors helper functions
extension FlexBuffersWriter {
  @inline(__always)
  public mutating func vector(key: String, _ closure: @escaping () -> Void) -> UInt64 {
    let start = startVector(key: key)
    closure()
    return endVector(start: start)
  }

  @inline(__always)
  public mutating func vector(_ closure: @escaping () -> Void) -> UInt64 {
    let start = startVector()
    closure()
    return endVector(start: start)
  }
}

// MARK: - Maps helper functions
extension FlexBuffersWriter {
  @inline(__always)
  public mutating func map(key: String, _ closure: @escaping () -> Void) -> UInt64 {
    let start = startMap(key: key)
    closure()
    return endMap(start: start)
  }

  @inline(__always)
  public mutating func map(_ closure: @escaping () -> Void) -> UInt64 {
    let start = startMap()
    closure()
    return endMap(start: start)
  }
}
