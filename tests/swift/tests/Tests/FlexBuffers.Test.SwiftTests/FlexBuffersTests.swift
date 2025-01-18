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

import XCTest
@testable import Common
@testable import FlexBuffers

final class FlexBuffersTests: XCTestCase {
  func testDeallocation() {
    let buf: ByteBuffer = {
      var fbx = FlexBuffersWriter()
      fbx.write(string: "Hello")
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
    let end = fbx.vector {
      let arr: [Int32] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 20]
      $0.create(vector: arr, fixed: false)
    }
    fbx.finish()
    let buf: ByteBuffer = fbx.sizedByteBuffer
    
    buf.withUnsafeBytes {
      XCTAssertEqual(
        Array($0),
        [10, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0, 5, 0, 0, 0, 6, 0, 0, 0, 7, 0, 0, 0, 8, 0, 0, 0, 9, 0, 0, 0, 20, 0, 0, 0, 1, 41, 46, 2, 40, 1])
    }
  }
}
