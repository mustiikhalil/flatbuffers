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

@inline(__always)
private func check(_ v: UInt64, width: UInt64) -> Bool {
  (v & ~((1 << width) &- 1)) == 0
}

@inline(__always)
internal func widthU(_ v: UInt64) -> BitWidth {
  if check(v, width: 8) { return .w8 }
  if check(v, width: 16) { return .w16 }
  if check(v, width: 32) { return .w32 }
  return .w64
}

@inline(__always)
internal func packedType(bitWidth: BitWidth, type: FlexBufferType) -> UInt8 {
  UInt8(bitWidth.rawValue | (type.rawValue << 2))
}
