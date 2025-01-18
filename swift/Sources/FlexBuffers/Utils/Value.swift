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

@usableFromInline
struct Value {
  
  @usableFromInline
  enum Union {
    case i(Int64)
    case u(UInt64)
    case f(Double)
  }
  let sloc: Union
  let type: FlexBufferType
  let bitWidth: BitWidth
  
  @usableFromInline
  var i: Int64 {
    switch sloc {
    case .i(let v): v
    default: 0
    }
  }
  
  @usableFromInline
  var u: UInt64 {
    switch sloc {
    case .u(let v): v
    default: 0
    }
  }
  
  @usableFromInline
  var f: Double {
    switch sloc {
    case .f(let v): v
    default: 0
    }
  }
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
        let offset = offsetLoc &- u

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
