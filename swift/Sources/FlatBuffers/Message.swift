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

public protocol GRPCVerifiableMessage<Message> {
  associatedtype Message

  init(pointer: UnsafeRawBufferPointer)
  init(byteBuffer: ByteBuffer)

  mutating func decode() throws -> Message
  func withUnsafeReadableBytes<Data>(_ body: (UnsafeRawBufferPointer) throws -> Data) rethrows -> Data
}

public struct GRPCMessage<Table: FlatBufferVerifiableTable>: GRPCVerifiableMessage {
  public typealias Message = Table

  private var buffer: ByteBuffer

  public var size: Int { Int(buffer.size) }

  public init(pointer: UnsafeRawBufferPointer) {
    buffer = ByteBuffer(copyingMemoryBound: pointer.baseAddress!, capacity: pointer.count)
  }

  public init(byteBuffer: ByteBuffer) {
    buffer = byteBuffer
  }

  public mutating func decode() throws -> Table {
    try getCheckedRoot(byteBuffer: &buffer)
  }

  @discardableResult
  @inline(__always)
  public func withUnsafeReadableBytes<Data>(
    _ body: (UnsafeRawBufferPointer) throws
      -> Data) rethrows -> Data
  {
    return try buffer.readWithUnsafeRawPointer(position: buffer.reader) {
      try body(UnsafeRawBufferPointer(start: $0, count: size))
    }
  }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public struct FlatBuffersMessageSerializer<Message: GRPCVerifiableMessage>: Sendable {
  public init() {}

  public func serialize(message: Message) throws -> [UInt8] {
    return message.withUnsafeReadableBytes {
      .init($0)
    }
  }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public struct FlatBuffersMessageDeserializer<Message: GRPCVerifiableMessage>: Sendable {
  public init() {}

  public func deserialize(pointer: UnsafeRawBufferPointer) throws -> Message {
    Message.init(pointer: pointer)
  }
}
