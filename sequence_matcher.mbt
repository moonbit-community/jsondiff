///|
/// A contiguous matching block between two sequences.
///
/// The coordinates are half-open intervals:
/// - In the first sequence: `[first_start, first_start + size)`
/// - In the second sequence: `[second_start, second_start + size)`
#valtype
priv struct Match {
  first_start : Int
  second_start : Int
  size : Int
}

///|
/// Build a `Match` value.
fn Match::new(first_start : Int, second_start : Int, size : Int) -> Match {
  Match::{ first_start, second_start, size }
}

///|
/// Operation tag used in an edit script.
///
/// - `Equal`: unchanged range in both sequences.
/// - `Insert`: range only exists in the second sequence.
/// - `Delete`: range only exists in the first sequence.
/// - `Replace`: range changed from first to second.
priv enum OpTag {
  Equal
  Insert
  Delete
  Replace
} derive(Eq)

///|
/// One edit operation over two half-open intervals.
///
/// The operation always compares:
/// - first sequence range: `[first_start, first_end)`
/// - second sequence range: `[second_start, second_end)`
priv struct OpCode {
  tag : OpTag
  first_start : Int
  first_end : Int
  second_start : Int
  second_end : Int
}

///|
/// Build an `OpCode` value.
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
/// Sequence matcher used to compute LCS-like matching blocks and diff opcodes.
///
/// Internal cache `second_sequence_elements` maps each element in the second
/// sequence to all its indices, which is reused by longest-match search.
priv struct SequenceMatcher[T] {
  mut first_sequence : Array[T]
  mut second_sequence : Array[T]
  mut second_sequence_elements : @hashmap.HashMap[T, Array[Int]]
}

///|
/// Construct a matcher for two sequences.
///
/// `T` must support `Eq + Hash`, because matching uses hash-map based index
/// lookups in `second_sequence_elements`.
fn[T : Eq + Hash] SequenceMatcher::new(
  first_sequence : Array[T],
  second_sequence : Array[T],
) -> SequenceMatcher[T] {
  let matcher = SequenceMatcher::{
    first_sequence,
    second_sequence,
    second_sequence_elements: @hashmap.HashMap::new(),
  }
  matcher.set_seqs(first_sequence, second_sequence)
  matcher
}

///|
/// Replace both sequences.
///
/// This updates the first sequence directly, then rebuilds the second-sequence
/// index cache through `set_second_seq`.
fn[T : Eq + Hash] SequenceMatcher::set_seqs(
  self : SequenceMatcher[T],
  first_sequence : Array[T],
  second_sequence : Array[T],
) -> Unit {
  self.set_first_seq(first_sequence)
  self.set_second_seq(second_sequence)
}

///|
/// Replace only the first sequence.
///
/// No cache rebuild is needed because the cache is keyed by the second
/// sequence.
fn[T] SequenceMatcher::set_first_seq(
  self : SequenceMatcher[T],
  sequence : Array[T],
) -> Unit {
  self.first_sequence = sequence
}

///|
/// Replace only the second sequence and rebuild its index cache.
fn[T : Eq + Hash] SequenceMatcher::set_second_seq(
  self : SequenceMatcher[T],
  sequence : Array[T],
) -> Unit {
  self.second_sequence = sequence
  self.chain_second_seq()
}

///|
/// Build an index map from second-sequence element to all its positions.
///
/// For long sequences, very frequent elements are filtered out to avoid
/// quadratic blowups in candidate expansion (`popular elements` optimization).
fn[T : Eq + Hash] SequenceMatcher::chain_second_seq(
  self : SequenceMatcher[T],
) -> Unit {
  let second_sequence = self.second_sequence
  let mut second_sequence_elements = @hashmap.HashMap::new()
  for i, item in second_sequence.iter2() {
    // Collect all indices where each element appears.
    let counter = second_sequence_elements.get_or_init(item, () => Array::new())
    counter.push(i)
  }

  // Keep only non-popular elements in the lookup table.
  // Threshold follows difflib-style heuristic: frequency > len/100 + 1.
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
/// Find the longest contiguous common block within two sub-ranges.
///
/// Search space is restricted to:
/// - first sequence range `[first_start, first_end)`
/// - second sequence range `[second_start, second_end)`
///
/// The core dynamic-programming state `j2len` stores the best length of a
/// suffix match ending at the current `i` and each `j`.
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

  // DP over diagonals: if first[i] == second[j],
  // new_j2len[j] = j2len[j - 1] + 1.
  for i = first_start; i < first_end; i = i + 1 {
    let item = first_sequence[i]
    let new_j2len = @hashmap.HashMap::new()
    match second_sequence_elements.get(item) {
      Some(indexes) =>
        for j in indexes {
          // Candidate index belongs to the current second-range window.
          if j < second_start {
            continue
          }
          if j >= second_end {
            break
          }

          // Extend previous diagonal match by one.
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

  // Extend around the best core match to absorb adjacent equal elements.
  // Two passes are used so a backward extension discovered in pass 1 can
  // enable additional forward extension in pass 2.

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
/// Compute edit operations that transform the first sequence into the second.
///
/// The algorithm:
/// 1. Repeatedly find longest matches inside unmatched windows.
/// 2. Sort and merge adjacent matches.
/// 3. Convert gaps between matches into `Insert/Delete/Replace` operations.
/// 4. Emit `Equal` operations for each merged match.
fn[T : Eq + Hash] SequenceMatcher::get_opcodes(
  self : SequenceMatcher[T],
) -> Array[OpCode] {
  let first_length = self.first_sequence.length()
  let second_length = self.second_sequence.length()
  let matches = Array::new()
  let queue = Array::new()
  queue.push((0, first_length, 0, second_length))

  // Split problem recursively (implemented with an explicit stack/queue).
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

  // Ensure deterministic order before merging.
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

  // Merge consecutive blocks that are contiguous in both sequences.
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
  let opcodes = Array::new()
  let mut i = 0
  let mut j = 0

  // Emit gap operations, then emit the equal block itself.
  for m in non_adjacent {
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
