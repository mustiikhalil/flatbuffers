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
import FlexBuffers
import Foundation
import XCTest

struct Subject: FlexBufferEncodable {
  let id: UUID = UUID()
  let name: String

  func encode<T>(_ writer: inout T) where T : Encoder {
    writer.encode(id, key: "id")
    writer.encode(name, key: "name")
  }
}

struct SomeValue: FlexBufferEncodable {
  let id: UUID
  let name: String
  let age: UInt8
  let address: String
  let isStudent: Bool
  let subjects: [Subject]

  func encode<T>(_ writer: inout T) where T : Encoder {
    writer.encode(id, key: "id")
    writer.encode(name, key: "name")
    writer.encode(age, key: "age")
    writer.encode(address, key: "address")
    writer.encode(isStudent, key: "student")
    writer.encode(subjects, key: "subjects")
  }
}


final class FlexBuffersEncoderTests: XCTestCase {
  func testEncoder() throws {
    var encoder = FlexBuffersEncoder()
    let someValue = SomeValue(
      id: UUID(),
      name: "John",
      age: 20,
      address: "New York",
      isStudent: true,
      subjects: [
        Subject(name: "Math"),
        Subject(name: "CS101"),
      ])

    let val = encoder.encode(someValue)
    let reference = try getRoot(buffer: ByteBuffer(data: val))!

    XCTAssertEqual(reference.type, .map)
    let map = reference.map

    XCTAssertEqual(map?.count, 6)
    XCTAssertEqual(map?["id"]?.cString, someValue.id.uuidString)
    XCTAssertEqual(map?["name"]?.cString, someValue.name)
    XCTAssertEqual(map?["age"]?.asUInt(), someValue.age)
    XCTAssertEqual(map?["address"]?.cString, someValue.address)
    XCTAssertEqual(map?["student"]?.bool, someValue.isStudent)

    let vector = map?["subjects"]?.vector

    XCTAssertEqual(vector?.count, 2)

    XCTAssertEqual(
      vector?[0]?.map?["id"]?.string(),
      someValue.subjects[0].id.uuidString)
    XCTAssertEqual(
      vector?[1]?.map?["id"]?.string(),
      someValue.subjects[1].id.uuidString)
    XCTAssertEqual(
      vector?[0]?.map?["name"]?.string(),
      someValue.subjects[0].name)
    XCTAssertEqual(
      vector?[1]?.map?["name"]?.string(),
      someValue.subjects[1].name)
  }
}
