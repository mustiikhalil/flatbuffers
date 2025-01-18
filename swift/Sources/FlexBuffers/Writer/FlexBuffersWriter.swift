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

@_exported import Common
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
  private var minBitWidth: BitWidth = .w8
  private var _bb: _InternalByteBuffer
  private var stack: [Value] = []

  public init(initialSize: Int = 1024) {
    _bb = _InternalByteBuffer(initialSize: initialSize)
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

  @inline(__always)
  mutating func endVector(start: Int, typed: Bool = false, fixed: Bool = false) -> UInt64 {
    let vec = createVector(
      start: start,
      count: stack.count - start,
      step: 1,
      typed: typed,
      fixed: fixed)
    stack.removeLast(1)
    stack.append(vec)
    return vec.u
  }
  
  @inline(__always)
  mutating func createVector(start: Int, count: Int, step: Int, typed: Bool, fixed: Bool, keys: Int? = nil) -> Value {
    assert(!fixed || typed, "Typed false and fixed true is a combination not supported currently")
    
    var bitWidth = BitWidth.max(minBitWidth, rhs: widthU(UInt64(count)))
    var prefixElements = 1
    if let keys {
      //      // If this vector is part of a map, we will pre-fix an offset to the keys
      //      // to this vector.
      //      bit_width = (std::max)(bit_width, keys->ElemWidth(buf_.size(), 0));
      //      prefix_elems += 2;
    }
    var vectorType: FlexBufferType = .key
    
    for i in stride(from: start, to: stack.count, by: step) {
      let elemWidth = stack[i].elementWidth(size: _bb.writerIndex, index: UInt64(i &- start &+ prefixElements))
      let bitWidth = BitWidth.max(bitWidth, rhs: elemWidth)
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
    
    if let keys {
//      WriteOffset(keys->u_, byte_width);
//      Write<uint64_t>(1ULL << keys->min_bit_width_, byte_width);
    }
    
    if !fixed {
      write(value: count, byteWidth: byteWidth)
    }

    var vloc = _bb.writerIndex
    
    for i in stride(from: start, to: stack.count, by: step) {
      write(any: stack[i], byteWidth: byteWidth)
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

  mutating func create<T>(vector: [T], fixed: Bool) -> Int where T: Scalar {
    let length = UInt64(vector.count)
    var vectorType = getScalarType(type: T.self)
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
        bitWidth: bitWidth)
    )
    return vloc
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
  
  // MARK: - Writing Scalars
  
  @inline(__always)
  public mutating func write(offset: UInt64, byteWidth: Int) {
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
    case .int: write(value: any.i, byteWidth: byteWidth)
    default:
      write(offset: any.u, byteWidth: byteWidth)
    }
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
    stack.append(Value(sloc: .u(UInt64(sloc)), type: type, bitWidth: bitWidth))
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

  @discardableResult
  @inline(__always)
  public mutating func vector(_ closure: @escaping (inout FlexBuffersWriter) -> Void) -> UInt64 {
    let start = startVector()
    closure(&self)
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
