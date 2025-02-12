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
import XCTest

final class FlexBuffersWriterTests: XCTestCase {
  func testDeallocation() {
    let buf: ByteBuffer = {
      var fbx = FlexBuffersWriter()
      fbx.add(string: "Hello")
      fbx.finish()
      return fbx.sizedByteBuffer
    }()

    buf.withUnsafeBytes {
      XCTAssertEqual(
        Array($0),
        [5, 72, 101, 108, 108, 111, 0, 6, 20, 1])
    }
  }

  func testAddingVectorOfScalars() {
    var fbx = FlexBuffersWriter()
    fbx.vector {
      let arr: [Int32] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 20]
      $0.create(vector: arr)
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer

    buf.withUnsafeBytes {
      // swiftformat:disable all
      XCTAssertEqual(
        Array($0),
        [10, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0, 5, 0, 0, 0, 6, 0, 0, 0, 7, 0, 0, 0, 8, 0, 0, 0, 9, 0, 0, 0, 20, 0, 0, 0, 1, 41, 46, 2, 40, 1])
      // swiftformat:enable all
    }
  }

  func testAddingVectorOfUnsignedScalars() {
    var fbx = FlexBuffersWriter()
    fbx.vector {
      let arr: [UInt] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 20]
      $0.create(vector: arr)
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer

    buf.withUnsafeBytes {
      // swiftformat:disable all
      XCTAssertEqual(
        Array($0),
        [10, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 20, 0, 0, 0, 0, 0, 0, 0, 1, 81, 51, 2, 40, 1])
      // swiftformat:enable all
    }
  }

  func testAddingVectorOfBools() {
    var fbx = FlexBuffersWriter()
    fbx.vector {
      let arr: [Bool] = [true, false, true, false]
      $0.create(vector: arr)
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer

    buf.withUnsafeBytes {
      // swiftformat:disable all
      XCTAssertEqual(
        Array($0),
        [4, 1, 0, 1, 0, 1, 5, 144, 2, 40, 1])
      // swiftformat:enable all
    }
  }

  func testSortingWithinMap() {
    var fbx = FlexBuffersWriter()
    fbx.map {
      $0.add(bool: false, key: "bool2")
      $0.add(bool: true, key: "bool1")
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer
    buf.withUnsafeBytes {
      // swiftformat:disable all
      XCTAssertEqual(
        Array($0),
        [98, 111, 111, 108, 50, 0, 98, 111, 111, 108, 49, 0, 2, 7, 14, 2, 1, 2, 1, 0, 104, 104, 4, 36, 1]
      )
      // swiftformat:enable all
    }
  }

  func testSharingKeyWithinMap() {
    var fbx = FlexBuffersWriter(initialSize: 1000, flags: .shareKeysAndStrings)
    fbx.map {
      $0.add(string: "welcome", key: "welcome")
      $0.add(string: "welcome", key: "welcome")
      $0.add(string: "welcome", key: "welcome")
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer
    buf.withUnsafeBytes {
      // swiftformat:disable all
      XCTAssertEqual(
        Array($0),
        [119, 101, 108, 99, 111, 109, 101, 0, 7, 119, 101, 108, 99, 111, 109, 101, 0, 3, 18, 19, 20, 3, 1, 3, 15, 16, 17, 20, 20, 20, 6, 36, 1]
      )
      // swiftformat:enable all
    }
  }
}
