///|
fn[T : Show] print_opcodes(
  opcodes : Array[OpCode],
  old~ : Array[T],
  new~ : Array[T],
) -> String {
  let buf = StringBuilder::new()
  for opcode in opcodes {
    match opcode.tag {
      Delete =>
        for i in opcode.first_start..<opcode.first_end {
          buf.write_string("- ")
          buf.write_object(old[i])
          buf.write_char('\n')
        }
      Insert =>
        for i in opcode.second_start..<opcode.second_end {
          buf.write_string("+ ")
          buf.write_object(new[i])
          buf.write_char('\n')
        }
      Equal =>
        for i in opcode.first_start..<opcode.first_end {
          buf.write_string("  ")
          buf.write_object(old[i])
          buf.write_char('\n')
        }
      Replace => {
        for i in opcode.first_start..<opcode.first_end {
          buf.write_string("- ")
          buf.write_object(old[i])
          buf.write_char('\n')
        }
        for i in opcode.second_start..<opcode.second_end {
          buf.write_string("+ ")
          buf.write_object(new[i])
          buf.write_char('\n')
        }
      }
    }
  }
  buf.to_string()
}

///|
test "SequenceMatcher - empty sequences" {
  let empty1 : Array[Int] = []
  let empty2 : Array[Int] = []
  let matcher = SequenceMatcher::new(empty1, empty2)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 0)
}

///|
test "SequenceMatcher - identical sequences" {
  let seq1 = [1, 2, 3, 4, 5]
  let seq2 = [1, 2, 3, 4, 5]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 1)
  inspect(
    print_opcodes(opcodes, old=seq1, new=seq2),
    content=(
      #|  1
      #|  2
      #|  3
      #|  4
      #|  5
      #|
    ),
  )
}

///|
test "SequenceMatcher - complete replacement" {
  let old = ["a", "b", "c"]
  let new = ["x", "y", "z"]
  let matcher = SequenceMatcher::new(old, new)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 1)
  inspect(
    print_opcodes(opcodes, old~, new~),
    content=(
      #|- "a"
      #|- "b"
      #|- "c"
      #|+ "x"
      #|+ "y"
      #|+ "z"
      #|
    ),
  )
}

///|
test "SequenceMatcher - insertion at beginning" {
  let old = ["b", "c", "d"]
  let new = ["a", "b", "c", "d"]
  let matcher = SequenceMatcher::new(old, new)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 2)
  inspect(
    print_opcodes(opcodes, old~, new~),
    content=(
      #|+ "a"
      #|  "b"
      #|  "c"
      #|  "d"
      #|
    ),
  )
}

///|
test "SequenceMatcher - deletion at end" {
  let old = ["a", "b", "c", "d"]
  let new = ["a", "b"]
  let matcher = SequenceMatcher::new(old, new)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 2)
  assert_true(opcodes[0].tag == Equal)
  assert_true(opcodes[1].tag == Delete)
  inspect(
    print_opcodes(opcodes, old~, new~),
    content=(
      #|  "a"
      #|  "b"
      #|- "c"
      #|- "d"
      #|
    ),
  )
}

///|
test "SequenceMatcher - complex mixed operations" {
  let old = ["a", "b", "c", "d", "e"]
  let new = ["a", "x", "y", "d", "e", "f"]
  let matcher = SequenceMatcher::new(old, new)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 4)
  inspect(
    print_opcodes(opcodes, old~, new~),
    content=(
      #|  "a"
      #|- "b"
      #|- "c"
      #|+ "x"
      #|+ "y"
      #|  "d"
      #|  "e"
      #|+ "f"
      #|
    ),
  )
}

///|
test "SequenceMatcher - duplicates" {
  let old = ["a", "b", "c"]
  let new = ["a", "a", "b", "b", "b", "c"]
  let matcher = SequenceMatcher::new(old, new)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 4)
  inspect(
    print_opcodes(opcodes, old~, new~),
    content=(
      #|+ "a"
      #|  "a"
      #|  "b"
      #|+ "b"
      #|+ "b"
      #|  "c"
      #|
    ),
  )
}

///|
test "SequenceMatcher - popular elements optimization" {
  // Test with sequences large enough to trigger the optimization path
  let seq1 = Array::makei(450, fn(i) { "\{i % 10}" })
  let seq2 = Array::makei(450, fn(i) { "\{i % 10}" })
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  assert_eq(opcodes.length(), 1)
  assert_true(opcodes[0].tag == Equal)
}

///|
test "SequenceMatcher - candidate index range guards" {
  let first = ["x", "k", "x"]
  let second = ["x", "k", "x", "k", "x"]
  let matcher = SequenceMatcher::new(first, second)
  let m = matcher.find_longest_match(0, first.length(), 1, 4)
  assert_true(m.size > 0)
}

///|
test "SequenceMatcher - backward and forward extension" {
  let seq1 = Array::makei(220, fn(i) { "u\{i}" })
  let seq2 = Array::makei(220, fn(i) { "u\{i}" })
  for i in 100..<110 {
    seq1[i] = "hot"
    seq2[i] = "hot"
  }
  let matcher = SequenceMatcher::new(seq1, seq2)
  let m = matcher.find_longest_match(90, 120, 90, 120)
  assert_eq(m.first_start, 90)
  assert_eq(m.second_start, 90)
  assert_eq(m.size, 30)
}
