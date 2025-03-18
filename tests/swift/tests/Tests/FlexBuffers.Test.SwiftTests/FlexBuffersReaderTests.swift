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

final class FlexBuffersReaderTests: XCTestCase {

  func testReadingProperBuffer() throws {
    let buf: ByteBuffer = createProperBuffer().byteBuffer

    let reference = try getRoot(buffer: buf)
    XCTAssertEqual(reference.type, .map)
    let map = reference.map
    XCTAssertEqual(map?.count, 7)
  }

  func testReadingSizedBuffer() throws {
    let buf: ByteBuffer = createSizedBuffer()

    buf.withUnsafeBytes { print(Array($0)) }

    let reference = try getRoot(buffer: buf)
    XCTAssertEqual(reference.type, .map)
    let map = reference.map
    XCTAssertEqual(map?.count, 7)
  }
}
