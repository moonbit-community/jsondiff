///|
test "SequenceMatcher - empty sequences" {
  let empty1 : Array[Int] = []
  let empty2 : Array[Int] = []
  let matcher = SequenceMatcher::new(empty1, empty2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="0")
}

///|
test "SequenceMatcher - identical sequences" {
  let seq1 = [1, 2, 3, 4, 5]
  let seq2 = [1, 2, 3, 4, 5]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="1")
  inspect(opcodes[0].tag == Equal, content="true")
  inspect(opcodes[0].first_start, content="0")
  inspect(opcodes[0].first_end, content="5")
  inspect(opcodes[0].second_start, content="0")
  inspect(opcodes[0].second_end, content="5")
}

///|
test "SequenceMatcher - complete replacement" {
  let seq1 = ["a", "b", "c"]
  let seq2 = ["x", "y", "z"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="1")
  inspect(opcodes[0].tag == Replace, content="true")
  inspect(opcodes[0].first_start, content="0")
  inspect(opcodes[0].first_end, content="3")
  inspect(opcodes[0].second_start, content="0")
  inspect(opcodes[0].second_end, content="3")
}

///|
test "SequenceMatcher - insertion at beginning" {
  let seq1 = ["b", "c", "d"]
  let seq2 = ["a", "b", "c", "d"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="2")
  inspect(opcodes[0].tag == Insert, content="true")
  inspect(opcodes[1].tag == Equal, content="true")
}

///|
test "SequenceMatcher - deletion at end" {
  let seq1 = ["a", "b", "c", "d"]
  let seq2 = ["a", "b"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="2")
  inspect(opcodes[0].tag == Equal, content="true")
  inspect(opcodes[1].tag == Delete, content="true")
  inspect(opcodes[1].first_start, content="2")
  inspect(opcodes[1].first_end, content="4")
}

///|
test "SequenceMatcher - complex mixed operations" {
  let seq1 = ["a", "b", "c", "d", "e"]
  let seq2 = ["a", "x", "y", "d", "e", "f"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()

  // Should have: Equal(a), Replace(b,c->x,y), Equal(d,e), Insert(f)
  inspect(opcodes.length() > 1, content="true")
  inspect(opcodes[0].tag == Equal, content="true") // "a"
}

///|
test "SequenceMatcher - find_longest_match specific range" {
  let seq1 = ["a", "b", "c", "d", "e"]
  let seq2 = ["x", "b", "c", "y", "e"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let match_result = matcher.find_longest_match(1, 4, 1, 4)
  inspect(match_result.size, content="2") // "b", "c"
  inspect(match_result.first_start, content="1")
  inspect(match_result.second_start, content="1")
}

///|
test "SequenceMatcher - get_matching_blocks" {
  let seq1 = ["a", "b", "c", "x", "d", "e"]
  let seq2 = ["a", "b", "y", "d", "e", "f"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let blocks = matcher.get_matching_blocks()

  // Should find matches for "a,b" and "d,e"
  inspect(blocks.length() >= 2, content="true")

  // Check final sentinel block
  let last_block = blocks[blocks.length() - 1]
  inspect(last_block.size, content="0")
}

///|
test "SequenceMatcher - chain_second_seq with duplicates" {
  let seq1 = ["a", "b", "c"]
  let seq2 = ["a", "a", "b", "b", "b", "c"]
  let matcher = SequenceMatcher::new(seq1, seq2)

  // Test that duplicates are handled correctly
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length() > 0, content="true")
}

///|
test "SequenceMatcher - large sequence optimization" {
  // Test with sequences large enough to trigger the optimization path
  let seq1 = Array::makei(250, fn(i) { "item\{i}" })
  let seq2 = Array::makei(250, fn(i) { "item\{i}" })
  let matcher = SequenceMatcher::new(seq1, seq2)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length(), content="1")
  inspect(opcodes[0].tag == Equal, content="true")
}

///|
test "SequenceMatcher - set_seqs updates state" {
  let seq1 = ["a", "b"]
  let seq2 = ["a", "b"]
  let matcher = SequenceMatcher::new(seq1, seq2)

  // Get initial matching blocks
  let _ = matcher.get_matching_blocks()

  // Change sequences
  let new_seq1 = ["x", "y"]
  let new_seq2 = ["x", "y"]
  matcher.set_seqs(new_seq1, new_seq2)

  // Should recalculate matching blocks
  let blocks = matcher.get_matching_blocks()
  inspect(blocks.length() >= 1, content="true")
}

///|
test "SequenceMatcher - set_first_seq only" {
  let seq1 = ["a", "b"]
  let seq2 = ["a", "b"]
  let matcher = SequenceMatcher::new(seq1, seq2)
  let new_seq1 = ["x", "y"]
  matcher.set_first_seq(new_seq1)
  let opcodes = matcher.get_opcodes()
  inspect(opcodes.length() > 0, content="true")
}

///|
test "SequenceMatcher - Match constructor and operations" {
  let match1 = Match::new(0, 0, 5)
  inspect(match1.first_start, content="0")
  inspect(match1.second_start, content="0")
  inspect(match1.size, content="5")
}

///|
test "SequenceMatcher - OpCode constructor" {
  let opcode = OpCode::new(Equal, 0, 5, 0, 5)
  inspect(opcode.tag == Equal, content="true")
  inspect(opcode.first_start, content="0")
  inspect(opcode.first_end, content="5")
  inspect(opcode.second_start, content="0")
  inspect(opcode.second_end, content="5")
}
