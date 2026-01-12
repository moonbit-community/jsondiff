///|
#valtype
priv struct Match {
  first_start : Int
  second_start : Int
  size : Int
}

///|
fn Match::new(first_start : Int, second_start : Int, size : Int) -> Match {
  Match::{ first_start, second_start, size }
}

///|
priv enum OpTag {
  Equal
  Insert
  Delete
  Replace
} derive(Eq)

///|
priv struct OpCode {
  tag : OpTag
  first_start : Int
  first_end : Int
  second_start : Int
  second_end : Int
}

///|
fn OpCode::new(
  tag : OpTag,
  first_start : Int,
  first_end : Int,
  second_start : Int,
  second_end : Int,
) -> OpCode {
  OpCode::{ tag, first_start, first_end, second_start, second_end }
}

///|
priv struct SequenceMatcher[T] {
  mut first_sequence : Array[T]
  mut second_sequence : Array[T]
  mut matching_blocks : Array[Match]?
  mut second_sequence_elements : @hashmap.HashMap[T, Array[Int]]
}

///|
fn[T : Eq + Hash] SequenceMatcher::new(
  first_sequence : Array[T],
  second_sequence : Array[T],
) -> SequenceMatcher[T] {
  let matcher = SequenceMatcher::{
    first_sequence,
    second_sequence,
    matching_blocks: None,
    second_sequence_elements: @hashmap.HashMap::new(),
  }
  matcher.set_seqs(first_sequence, second_sequence)
  matcher
}

///|
fn[T : Eq + Hash] SequenceMatcher::set_seqs(
  self : SequenceMatcher[T],
  first_sequence : Array[T],
  second_sequence : Array[T],
) -> Unit {
  self.set_first_seq(first_sequence)
  self.set_second_seq(second_sequence)
}

///|
fn[T] SequenceMatcher::set_first_seq(
  self : SequenceMatcher[T],
  sequence : Array[T],
) -> Unit {
  self.first_sequence = sequence
  self.matching_blocks = None
}

///|
fn[T : Eq + Hash] SequenceMatcher::set_second_seq(
  self : SequenceMatcher[T],
  sequence : Array[T],
) -> Unit {
  self.second_sequence = sequence
  self.matching_blocks = None
  self.chain_second_seq()
}

///|
fn[T : Eq + Hash] SequenceMatcher::chain_second_seq(
  self : SequenceMatcher[T],
) -> Unit {
  let second_sequence = self.second_sequence
  let mut second_sequence_elements = @hashmap.HashMap::new()
  for i, item in second_sequence.iter2() {
    let counter = second_sequence_elements.get_or_init(item, () => Array::new())
    counter.push(i)
  }

  // keep popular elements in lookup table
  let len = second_sequence.length()
  if len >= 200 {
    let test_len = (len.to_double() / 100.0).floor().to_int() + 1
    let after_filter = @hashmap.HashMap::new()
    second_sequence_elements
    .iter()
    .each(fn(entry) {
      let (element, indexes) = entry
      if indexes.length() > test_len {
        after_filter.set(element, indexes)
      }
    })
    second_sequence_elements = after_filter
  }
  self.second_sequence_elements = second_sequence_elements
}

///|
fn[T : Eq + Hash] SequenceMatcher::find_longest_match(
  self : SequenceMatcher[T],
  first_start : Int,
  first_end : Int,
  second_start : Int,
  second_end : Int,
) -> Match {
  let first_sequence = self.first_sequence
  let second_sequence = self.second_sequence
  let second_sequence_elements = self.second_sequence_elements
  let mut best_i = first_start
  let mut best_j = second_start
  let mut best_size = 0
  let mut j2len = @hashmap.HashMap::new()
  for i = first_start; i < first_end; i = i + 1 {
    let item = first_sequence[i]
    let new_j2len = @hashmap.HashMap::new()
    match second_sequence_elements.get(item) {
      Some(indexes) =>
        for j in indexes {
          if j < second_start {
            continue
          }
          if j >= second_end {
            break
          }
          let mut size = match j2len.get(j - 1) {
            Some(k) if j > 0 => k
            _ => 0
          }
          size += 1
          new_j2len.set(j, size)
          if size > best_size {
            best_i = i + 1 - size
            best_j = j + 1 - size
            best_size = size
          }
        }
      None => ()
    }
    j2len = new_j2len
  }

  // Extend the match backwards and forwards

  for _ in 0..<2 {
    while best_i > first_start &&
          best_j > second_start &&
          first_sequence[best_i - 1] == second_sequence[best_j - 1] {
      best_i -= 1
      best_j -= 1
      best_size += 1
    }
    while best_i + best_size < first_end &&
          best_j + best_size < second_end &&
          first_sequence[best_i + best_size] ==
          second_sequence[best_j + best_size] {
      best_size += 1
    }
  }
  Match::new(best_i, best_j, best_size)
}

///|
fn[T : Eq + Hash] SequenceMatcher::get_matching_blocks(
  self : SequenceMatcher[T],
) -> Array[Match] {
  if self.matching_blocks is Some(blocks) {
    return blocks
  }
  let first_length = self.first_sequence.length()
  let second_length = self.second_sequence.length()
  let matches = Array::new()
  let queue = Array::new()
  queue.push((0, first_length, 0, second_length))
  while !queue.is_empty() {
    let (first_start, first_end, second_start, second_end) = queue.unsafe_pop()
    let m = self.find_longest_match(
      first_start, first_end, second_start, second_end,
    )
    if m.size > 0 {
      if first_start < m.first_start && second_start < m.second_start {
        queue.push((first_start, m.first_start, second_start, m.second_start))
      }
      if m.first_start + m.size < first_end &&
        m.second_start + m.size < second_end {
        queue.push(
          (
            m.first_start + m.size,
            first_end,
            m.second_start + m.size,
            second_end,
          ),
        )
      }
      matches.push(m)
    }
  }

  // Sort matches
  matches.sort_by(fn(a, b) {
    if a.first_start < b.first_start {
      -1
    } else if a.first_start > b.first_start {
      1
    } else if a.second_start < b.second_start {
      -1
    } else if a.second_start > b.second_start {
      1
    } else {
      a.size.compare(b.size)
    }
  })

  // Merge adjacent matches
  let mut first_start = 0
  let mut second_start = 0
  let mut size = 0
  let non_adjacent = Array::new()
  for m in matches {
    if first_start + size == m.first_start &&
      second_start + size == m.second_start {
      size += m.size
    } else {
      if size != 0 {
        non_adjacent.push(Match::new(first_start, second_start, size))
      }
      first_start = m.first_start
      second_start = m.second_start
      size = m.size
    }
  }
  if size != 0 {
    non_adjacent.push(Match::new(first_start, second_start, size))
  }
  non_adjacent.push(Match::new(first_length, second_length, 0))
  self.matching_blocks = Some(non_adjacent)
  non_adjacent
}

///|
fn[T : Eq + Hash] SequenceMatcher::get_opcodes(
  self : SequenceMatcher[T],
) -> Array[OpCode] {
  let opcodes = Array::new()
  let mut i = 0
  let mut j = 0
  for m in self.get_matching_blocks() {
    let tag = if i < m.first_start && j < m.second_start {
      Some(OpTag::Replace)
    } else if i < m.first_start {
      Some(Delete)
    } else if j < m.second_start {
      Some(Insert)
    } else {
      None
    }
    if tag is Some(tag) {
      opcodes.push(OpCode::new(tag, i, m.first_start, j, m.second_start))
    }
    i = m.first_start + m.size
    j = m.second_start + m.size
    if m.size != 0 {
      opcodes.push(OpCode::new(Equal, m.first_start, i, m.second_start, j))
    }
  }
  opcodes
}
