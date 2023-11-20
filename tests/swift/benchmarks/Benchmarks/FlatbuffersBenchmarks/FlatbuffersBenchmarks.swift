/*
 * Copyright 2023 Google Inc. All rights reserved.
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

import Benchmark
import CoreFoundation
import FlatBuffers

@usableFromInline
struct AA: NativeStruct {
  public init(a: Double, b: Double) {
    self.a = a
    self.b = b
  }
  var a: Double
  var b: Double
}

let benchmarks = {
  let ints: [Int] = Array(repeating: 42, count: 100)
  let bytes: [UInt8] = Array(repeating: 42, count: 100)
  let str = (0...99).map { _ -> String in "x" }.joined()
  let array: [AA] = [
    AA(a: 2.4, b: 2.4),
    AA(a: 2.4, b: 2.4),
    AA(a: 2.4, b: 2.4),
    AA(a: 2.4, b: 2.4),
    AA(a: 2.4, b: 2.4),
  ]

  Benchmark("Allocating") { benchmark in
    for i in benchmark.scaledIterations {
      blackHole(FlatBufferBuilder(initialSize: 1_024_000_000))
    }
  }

  Benchmark("Strings 10") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        _ = fb.create(string: "foobarbaz")
      }
    }
    benchmark.stopMeasurement()
    fb.clear()
  }

  Benchmark("Strings 100") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        _ = fb.create(string: str)
      }
    }
    benchmark.stopMeasurement()
    fb.clear()
  }

  Benchmark("Vector 1 Bytes") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      _ = fb.createVector(bytes: bytes)
    }
    benchmark.stopMeasurement()
  }

  Benchmark("Vector 1 Ints") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      _ = fb.createVector(ints)
    }
    benchmark.stopMeasurement()
  }

  Benchmark("Vector 100 Ints") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        _ = fb.createVector(ints)
      }
    }
    benchmark.stopMeasurement()
  }

  Benchmark("Vector 100 Bytes") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        _ = fb.createVector(bytes)
      }
    }
    benchmark.stopMeasurement()
  }

  Benchmark("Vector 100 ContiguousBytes") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1<<20)
    benchmark.startMeasurement()
    for i in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        _ = fb.createVector(bytes: bytes)
      }
    }
    benchmark.stopMeasurement()
  }

  Benchmark("FlatBufferBuilder Add") { benchmark in
    var fb = FlatBufferBuilder(initialSize: 1024 * 1024 * 32)
    benchmark.startMeasurement()
    for _ in benchmark.scaledIterations {
      for _ in 0..<1_000_000 {
        let off = fb.create(string: "T")
        let s = fb.startTable(with: 4)
        fb.add(element: 3.2, def: 0, at: 2)
        fb.add(element: 4.2, def: 0, at: 4)
        fb.add(element: 5.2, def: 0, at: 6)
        fb.add(offset: off, at: 8)
        _ = fb.endTable(at: s)
      }
    }
    benchmark.stopMeasurement()
    fb.clear()
  }

  Benchmark("structs") { benchmark in
    let structCount = 1_000_000

    let rawSize = ((16 * 5) * structCount) / 1024

    var fb = FlatBufferBuilder(initialSize: Int32(rawSize * 1600))

    benchmark.startMeasurement()
    for _ in benchmark.scaledIterations {
      var offsets: [Offset] = []
      for _ in 0..<structCount {
        let vector = fb.createVector(
          ofStructs: array)
        let start = fb.startTable(with: 1)
        fb.add(offset: vector, at: 4)
        offsets.append(Offset(offset: fb.endTable(at: start)))
      }
      let vector = fb.createVector(ofOffsets: offsets)
      let start = fb.startTable(with: 1)
      fb.add(offset: vector, at: 4)
      let root = Offset(offset: fb.endTable(at: start))
      fb.finish(offset: root)
    }
    benchmark.stopMeasurement()
    fb.clear()
  }
}
