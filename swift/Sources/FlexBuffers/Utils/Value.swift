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

struct Value {
  let sloc: UInt64
  let type: FlexBufferType
  let bitWidth: BitWidth
}

extension Value {
  @usableFromInline
  @inline(__always)
  func elementWidth(size: Int, index: UInt64) -> BitWidth {
    #warning("add inline check")
    if false {

    } else {
      for byteWidth in stride(from: 1, to: UInt64.max, by: 2) {
        let _offsetLoc = UInt64(size &+ padding(
          bufSize: size,
          elementSize: Int(byteWidth)))
        let offsetLoc = _offsetLoc &+ (index &* byteWidth)
        let offset = offsetLoc &- sloc

        let bitWidth = widthU(offset)
        if (UInt64.one << bitWidth.rawValue) == byteWidth {
          return bitWidth
        }
      }
      return .w64
    }
  }

  @inline(__always)
  func storedPackedType(width: BitWidth = .w8) -> UInt8 {
    packedType(bitWidth: storedWidth(width: width), type: type)
  }

  @inline(__always)
  private func storedWidth(width: BitWidth) -> BitWidth {
    #warning("add inline check")
    if false {
      return max(bitWidth, width)
    } else {
      return bitWidth
    }
  }
}
