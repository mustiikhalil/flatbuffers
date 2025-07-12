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

public protocol FlexBufferEncodable {
  func encode<T>(_ writer: inout T) where T: Encoder
}
public protocol FlexBufferDecodable {}

public protocol Encoder {
  // Bools
  mutating func encode(_ val: borrowing Bool, key: borrowing String)
//  func encode(_ val: borrowing Bool?, key: borrowing String)

  // Unsigned int
  mutating func encode(_ val: UInt8, key: borrowing String)
//  func encode(_ val: UInt8?, key: borrowing String)
//  func encode(_ val: UInt16, key: borrowing String)
//  func encode(_ val: UInt16?, key: borrowing String)
//  func encode(_ val: UInt32, key: borrowing String)
//  func encode(_ val: UInt32?, key: borrowing String)
//  func encode(_ val: UInt, key: borrowing String)
//  func encode(_ val: UInt?, key: borrowing String)
//  func encode(_ val: UInt64, key: borrowing String)
//  func encode(_ val: UInt64?, key: borrowing String)
//
//  // Signed int
//  func encode(_ val: Int8, key: borrowing String)
//  func encode(_ val: Int8?, key: borrowing String)
//  func encode(_ val: Int16, key: borrowing String)
//  func encode(_ val: Int16?, key: borrowing String)
//  func encode(_ val: Int32, key: borrowing String)
//  func encode(_ val: Int32?, key: borrowing String)
//  func encode(_ val: Int, key: borrowing String)
//  func encode(_ val: Int?, key: borrowing String)
//  func encode(_ val: Int64, key: borrowing String)
//  func encode(_ val: Int64?, key: borrowing String)
//
//  // Floats
//  func encode(_ val: Float, key: borrowing String)
//  func encode(_ val: Float?, key: borrowing String)
//  func encode(_ val: Double, key: borrowing String)
//  func encode(_ val: Double?, key: borrowing String)

  mutating func encode(_ val: String, key: borrowing String)
//  func encode(_ val: String?, key: borrowing String)

  mutating func encode(_ val: UUID, key: borrowing String)

//  func encode(_ val: Data, key: borrowing String)

  mutating func encode<T>(_ val: [T], key: borrowing String)
    where T: FlexBufferEncodable
//  mutating func encode<T>(_ val: T, key: borrowing String) where T: FlexBufferEncodable
}

extension FlexBuffersWriter: Encoder {
  public mutating func encode(_ val: borrowing Bool, key: borrowing String) {
    add(bool: val, key: key)
  }

  public mutating func encode(_ val: UInt8, key: borrowing String) {
    add(uint8: val, key: key)
  }

  public mutating func encode(_ val: String, key: borrowing String) {
    add(string: val, key: key)
  }

  public mutating func encode(_ val: UUID, key: borrowing String) {
    add(string: val.uuidString, key: key)
  }

  public mutating func encode<T>(_ values: [T], key: borrowing String)
    where T : FlexBufferEncodable
  {
    vector(key: key) { writer in
      for val in values {
        writer.map { map in
          val.encode(&map)
        }
      }
    }
  }
}


public struct FlexBuffersEncoder {
  public init(flags: BuilderFlag = .shareKeys) {
    _internalEncoder = FlexBuffersWriter(initialSize: 1_000_000, flags: flags)
  }

  public mutating func encode<T: FlexBufferEncodable>(_ value: T) -> Data {
    defer { _internalEncoder.reset() }
    _internalEncoder.map { writer in
      value.encode(&writer)
    }
    _internalEncoder.finish()
    return _internalEncoder.data
  }

  public mutating func encode<T: FlexBufferEncodable>(_ value: [T]) -> Data {
    return Data()
  }

  private lazy var _internalEncoder: FlexBuffersWriter = {
    FlexBuffersWriter()
  }()
}
