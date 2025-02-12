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

import Foundation

public typealias FlexBuffersWriterBuilder = (inout FlexBuffersWriter) -> Void

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
  private var hasDuplicatedKeys = false
  private var minBitWidth: BitWidth = .w8
  private var _bb: _InternalByteBuffer
  private var stack: [Value] = []
  private var keyPool: [Int: Int] = [:]
  private var stringPool: [Int: Int] = [:]
  private var flags: BuilderFlag

  public init(initialSize: Int = 1024, flags: BuilderFlag = .shareKeys) {
    _bb = _InternalByteBuffer(initialSize: initialSize)
    self.flags = flags
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
    return _bb.withUnsafeSlicedBytes {
      ByteBuffer(copyingMemoryBound: $0.baseAddress!, capacity: $0.count)
    }
  }

  /// Resets the internal state. Automatically called before building a new flexbuffer.
  public mutating func reset() {
    _bb.clear()
    stack.removeAll(keepingCapacity: true)
    finished = false
    #warning(
      "Implement the rest of the function to match the cpp implementation")
    // flags_ remains as-is;
    //    force_min_bit_width_ = BIT_WIDTH_8;
    //    key_pool.clear();
    //    string_pool.clear();
  }

  // MARK: - Vector
  @inline(__always)
  public func startVector() -> Int {
    stack.count
  }

  @inline(__always)
  public mutating func startVector(key k: String) -> Int {
    add(key: k)
    return stack.count
  }

  @inline(__always)
  public mutating func endVector(
    start: Int,
    typed: Bool = false,
    fixed: Bool = false) -> UInt64
  {
    let vec = createVector(
      start: start,
      count: stack.count - start,
      step: 1,
      typed: typed,
      fixed: fixed,
      keys: nil)
    stack.removeLast(1)
    stack.append(vec)
    return vec.u
  }

  @inline(__always)
  @discardableResult
  public mutating func create<T>(vector: [T]) -> Int where T: Scalar {
    create(vector: vector, fixed: false)
  }

  // MARK: - Map
  @inline(__always)
  public func startMap() -> Int {
    stack.count
  }

  @inline(__always)
  public mutating func startMap(key k: String) -> Int {
    add(key: k)
    return stack.count
  }

  @inline(__always)
  public mutating func endMap(start: Int) -> UInt64 {
    let len = sortMapByKeys(start: start)

    let keys = createVector(
      start: start,
      count: len,
      step: 2,
      typed: true,
      fixed: false)
    let vec = createVector(
      start: start + 1,
      count: len,
      step: 2,
      typed: false,
      fixed: false,
      keys: keys)
    stack = Array(stack[..<start])
    stack.append(vec)
    return UInt64(vec.u)
  }

  // MARK: - Writing Scalars

  @inline(__always)
  public mutating func add(bool: borrowing Bool) {
    stack.append(Value(bool: bool))
  }

  @inline(__always)
  public mutating func add(bool: borrowing Bool, key: borrowing String) {
    add(key: key)
    add(bool: bool)
  }

  // MARK: - Writing strings
  @inline(__always)
  public mutating func add(string: borrowing String, key: borrowing String) {
    add(key: key)
    write(str: string, len: string.count)
  }

  @inline(__always)
  public mutating func add(string: borrowing String) {
    write(str: string, len: string.count)
  }

  // MARK: - Storing root

  public mutating func finish() {
    assert(stack.count == 1)

    // Write root value.
    var byteWidth = align(width: stack[0].elementWidth(
      size: writerIndex,
      index: 0))

    write(value: stack[0], byteWidth: byteWidth)
    var storedType = stack[0].storedPackedType()
    // Write root type.
    _bb.writeBytes(&storedType, len: 1)
    // Write root size. Normally determined by parent, but root has no parent :)
    _bb.writeBytes(&byteWidth, len: 1)

    finished = true
  }

  // MARK: - Private -

  // MARK: Writing to buffer

  @inline(__always)
  private mutating func write(value: Value, byteWidth: Int) {
    switch value.type {
    case .null: fallthrough
    case .int: write(value: value.i, byteWidth: byteWidth)
    case .bool: fallthrough
    case .uint: write(value: value.u, byteWidth: byteWidth)
    default:
      write(offset: value.u, byteWidth: byteWidth)
    }
  }

  // MARK: Internal Writing Strings

  /// Adds a string to the buffer using swift.utf8 object
  /// - Parameter str: String that will be added to the buffer
  /// - Parameter len: length of the string
  @discardableResult
  @inline(__always)
  private mutating func write(str: borrowing String, len: Int) -> Int {
    let resetTo = writerIndex
    var sloc = str.withCString {
      storeBlob(pointer: $0, len: len, trailing: 1, type: .string)
    }

    if flags >= .shareKeysAndStrings {
      let loc = stringPool[str.hashValue]
      if let loc {
        writerIndex = resetTo
        sloc = loc
        assert(
          stack.count > 0,
          "Attempting to override the location, but stack is empty")
        stack[stack.count - 1].sloc = .u(UInt64(sloc))
      } else {
        stringPool[str.hashValue] = sloc
      }
    }
    return sloc
  }

  // MARK: Write Keys
  @discardableResult
  @inline(__always)
  private mutating func add(key: borrowing String) -> Int {
    add(key: key, len: key.count)
  }

  @discardableResult
  @inline(__always)
  private mutating func add(key: borrowing String, len: Int) -> Int {
    var sloc = writerIndex
    key.withCString {
      _bb.writeBytes($0, len: len + 1)
    }

    if flags > .shareKeys {
      let loc = keyPool[key.hashValue]
      if let loc {
        writerIndex = sloc
        sloc = loc
      } else {
        keyPool[key.hashValue] = sloc
      }
    }
    stack.append(Value(sloc: .u(UInt64(sloc)), type: .key, bitWidth: .w8))
    return sloc
  }

  // MARK: - Storing Blobs
  @inline(__always)
  private mutating func storeBlob(_ array: [UInt8]) {
    array.withUnsafeBufferPointer {
      #warning("Fix type to use array of blob")
      storeBlob(pointer: $0.baseAddress!, len: array.count, type: .string)
    }
  }

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
    stack.append(Value(sloc: .u(UInt64(sloc)), type: type, bitWidth: bitWidth))
    return sloc
  }

  // MARK: Write Vectors
  @inline(__always)
  @discardableResult
  private mutating func create<T>(vector: [T], fixed: Bool) -> Int
    where T: Scalar
  {
    let length = UInt64(vector.count)
    let vectorType = getScalarType(type: T.self)
    let byteWidth = MemoryLayout<T>.size
    let bitWidth = BitWidth.widthB(byteWidth)

    assert(widthU(length) <= bitWidth)

    align(width: bitWidth)

    if !fixed {
      write(value: length, byteWidth: byteWidth)
    }
    let vloc = _bb.writerIndex

    for i in stride(from: 0, to: vector.count, by: 1) {
      write(value: vector[i], byteWidth: byteWidth)
    }

    stack.append(
      Value(
        sloc: .u(UInt64(vloc)),
        type: toTypedVector(type: vectorType, length: fixed ? length : 0),
        bitWidth: bitWidth))
    return vloc
  }

  @inline(__always)
  private mutating func createVector(
    start: Int,
    count: Int,
    step: Int,
    typed: Bool,
    fixed: Bool,
    keys: Value? = nil) -> Value
  {
    assert(
      !fixed || typed,
      "Typed false and fixed true is a combination not supported currently")

    var bitWidth = BitWidth.max(minBitWidth, rhs: widthU(UInt64(count)))
    var prefixElements = 1
    if keys != nil {
      /// If this vector is part of a map, we will pre-fix an offset to the keys
      /// to this vector.
      bitWidth = max(bitWidth, keys!.elementWidth(size: writerIndex, index: 0))
      prefixElements += 2
    }
    var vectorType: FlexBufferType = .key

    for i in stride(from: start, to: stack.count, by: step) {
      let elemWidth = stack[i].elementWidth(
        size: _bb.writerIndex,
        index: UInt64(i &- start &+ prefixElements))
      bitWidth = BitWidth.max(bitWidth, rhs: elemWidth)
      guard typed else { continue }
      if i == start {
        vectorType = stack[i].type
      } else {
        assert(
          vectorType == stack[i].type,
          """
          If you get this assert you are writing a typed vector 
          with elements that are not all the same type
          """)
      }
    }
    assert(
      !typed || isTypedVectorType(type: vectorType),
      """
      If you get this assert, your typed types are not one of:
      Int / UInt / Float / Key.
      """)

    let byteWidth = align(width: bitWidth)

    if keys != nil {
      write(offset: keys!.u, byteWidth: byteWidth)
      write(value: UInt64.one << keys!.bitWidth.rawValue, byteWidth: byteWidth)
    }

    if !fixed {
      write(value: count, byteWidth: byteWidth)
    }

    let vloc = _bb.writerIndex

    for i in stride(from: start, to: stack.count, by: step) {
      write(value: stack[i], byteWidth: byteWidth)
    }

    if !typed {
      for i in stride(from: start, to: stack.count, by: step) {
        _bb.write(stack[i].storedPackedType(width: bitWidth), len: 1)
      }
    }

    let type: FlexBufferType = if keys != nil {
      .map
    } else if typed {
      toTypedVector(type: vectorType, length: UInt64(fixed ? count : 0))
    } else {
      .vector
    }

    return Value(sloc: .u(UInt64(vloc)), type: type, bitWidth: bitWidth)
  }

  // MARK: Write Scalar functions
  @inline(__always)
  private mutating func write(offset: UInt64, byteWidth: Int) {
    let offset = UInt64(writerIndex) &- offset
    assert(byteWidth == 8 || offset < UInt64.one << (byteWidth * 8))
    _ = withUnsafePointer(to: offset) {
      _bb.writeBytes($0, len: byteWidth)
    }
  }

  @inline(__always)
  private mutating func write<T>(value: T, byteWidth: Int) where T: Scalar {
    _ = withUnsafePointer(to: value) {
      _bb.writeBytes($0, len: byteWidth)
    }
  }

  // MARK: Misc functions
  @discardableResult
  @inline(__always)
  private mutating func align(width: BitWidth) -> Int {
    let bytes = Int(UInt64.one << width.rawValue)
    writerIndex = writerIndex &+ padding(bufSize: capacity, elementSize: bytes)
    return bytes
  }
}

// MARK: - Vectors helper functions
extension FlexBuffersWriter {
  @discardableResult
  @inline(__always)
  public mutating func vector(
    key: String,
    _ closure: @escaping FlexBuffersWriterBuilder) -> UInt64
  {
    let start = startVector(key: key)
    closure(&self)
    return endVector(start: start)
  }

  @discardableResult
  @inline(__always)
  public mutating func vector(_ closure: @escaping FlexBuffersWriterBuilder)
    -> UInt64
  {
    let start = startVector()
    closure(&self)
    return endVector(start: start)
  }
}

// MARK: - Maps helper functions
extension FlexBuffersWriter {
  @discardableResult
  @inline(__always)
  public mutating func map(
    key: String,
    _ closure: @escaping FlexBuffersWriterBuilder) -> UInt64
  {
    let start = startMap(key: key)
    closure(&self)
    return endMap(start: start)
  }

  @discardableResult
  @inline(__always)
  public mutating func map(_ closure: @escaping FlexBuffersWriterBuilder)
    -> UInt64
  {
    let start = startMap()
    closure(&self)
    return endMap(start: start)
  }
}

extension FlexBuffersWriter {
  @inline(__always)
  private mutating func sortMapByKeys(start: Int) -> Int {
    let len = mapElementCount(start: start)
    for index in stride(from: start, to: stack.count, by: 2) {
      assert(stack[index].type == .key)
    }

    struct TwoValue: Equatable {
      let key, value: Value
    }

    stack[start...].withUnsafeMutableBytes { buffer in
      var ptr = buffer.assumingMemoryBound(to: TwoValue.self)
      ptr.sort { a, b in
        let aMem = _bb.memory.advanced(by: Int(a.key.u))
          .assumingMemoryBound(to: CChar.self)
        let bMem = _bb.memory.advanced(by: Int(b.key.u))
          .assumingMemoryBound(to: CChar.self)
        let comp = strcmp(aMem, bMem)
        if (comp == 0) && a != b { hasDuplicatedKeys = true }
        return comp < 0
      }
    }
    return len
  }

  @inline(__always)
  private func mapElementCount(start: Int) -> Int {
    var len = stack.count - start
    assert((len & 1) == 0)
    len /= 2
    return len
  }
}
