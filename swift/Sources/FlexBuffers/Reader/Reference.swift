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

enum FlexBuffersErrors: Error {
  case sizeOfBufferIsTooSmall
  case typeCouldNotBeDetermined
}

@inline(__always)
public func getRoot(buffer: ByteBuffer) throws -> Reference {
  let end = buffer.count
  if buffer.count < 3 {
    throw FlexBuffersErrors.sizeOfBufferIsTooSmall
  }

  let byteWidth = buffer.read(def: UInt8.self, position: end &- 1)
  let packedType = buffer.read(def: UInt8.self, position: end &- 2)
  let offset = end &- 2 &- numericCast(byteWidth);

  return try Reference(
    buffer: buffer,
    offset: offset,
    parentWidth: byteWidth,
    packedType: packedType)
}


@inline(__always)
public func getRootChecked(buffer: ByteBuffer) throws -> Reference {
  #warning("TODO: Implement")
  return try getRoot(buffer: buffer)
}


public struct Reference {

  private let buffer: ByteBuffer
  private let offset: Int
  private let parentWidth: UInt8
  private let byteWidth: UInt8

  public let type: FlexBufferType

  init(
    buffer: ByteBuffer,
    offset: Int,
    parentWidth: UInt8,
    packedType: UInt8) throws
  {
    self.buffer = buffer
    self.offset = offset
    self.parentWidth = parentWidth
    byteWidth = 1 << (packedType & 3)
    guard let type = FlexBufferType(rawValue: UInt64(packedType >> 2)) else {
      throw FlexBuffersErrors.typeCouldNotBeDetermined
    }
    self.type = type
  }

  public var map: Map? {
    guard type == .map else { return nil }
    return Map(
      buffer: buffer,
      end: indirect(),
      byteWidth: byteWidth)
  }

  private func indirect() -> Int {
    readIndirect(buffer: buffer, offset: offset, parentWidth)
  }
}

func readIndirect(buffer: ByteBuffer, offset: Int, _ byteWidth: UInt8) -> Int {
  return offset &- numericCast(buffer.readUInt64(
    offset: offset,
    byteWidth: byteWidth))
}

public struct Map: Sized {
  private let buffer: ByteBuffer
  private let end: Int
  private let byteWidth: UInt8

  public let count: Int

  init(buffer: ByteBuffer, end: Int, byteWidth: UInt8) {
    self.buffer = buffer
    self.end = end
    self.byteWidth = byteWidth

    count = Self.getCount(buffer: buffer, end: end, byteWidth: byteWidth)
  }
}

public protocol Sized {
  var count: Int { get }
}

extension Sized {
  static func getCount(buffer: ByteBuffer, end: Int, byteWidth: UInt8) -> Int {
    Int(buffer.readUInt64(
      offset: end &- numericCast(byteWidth),
      byteWidth: byteWidth))
  }
}
