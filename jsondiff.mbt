///|
/// Auxiliary structure to encapsulate data about the structural difference
/// of two JSON files.
struct JsonDiff {
  /// Quantifies the difference between two JSON files.
  /// If `0.0`: the two JSON files are entirely different one from the other.
  /// If `100.0`: the two JSON files are identical.
  score : Double
  /// The JSON structural difference of two JSON files.
  /// If None: the two JSON files are identical.
  diff : JsonEdit?
}

///|
priv struct BestMatch {
  score : Double
  key : String
  index_distance : UInt
}

///|
fn BestMatch::new(
  score : Double,
  key : String,
  index_distance : UInt,
) -> BestMatch {
  BestMatch::{ score, key, index_distance }
}

///|
/// Finds the JSON structural difference of two JSON files.
pub fn JsonDiff::diff(
  json1 : Json,
  json2 : Json,
  keys_only? : Bool = false,
) -> JsonDiff {
  JsonDiff::diff_with_score(json1, json2, keys_only)
}

///|
/// Finds the JSON structural difference of two JSON files and
/// returns it as a formatted string.
pub fn JsonDiff::diff_string(
  json1 : Json,
  json2 : Json,
  keys_only? : Bool = false,
  terminal? : Bool = false,
) -> String? {
  let jsondiff = JsonDiff::diff(json1, json2, keys_only~)
  jsondiff.stringify(terminal~)
}

///|
fn JsonDiff::stringify(self : JsonDiff, terminal~ : Bool) -> String? {
  match self.diff {
    None => None
    Some(value) => Some(value.stringify(terminal~))
  }
}

///|
fn JsonDiff::object_diff(
  obj1 : Map[String, Json],
  obj2 : Map[String, Json],
  keys_only : Bool,
) -> JsonDiff {
  let diff = Map::new()
  let deleted = Map::new()
  let added = Map::new()
  let mut score = 0.0

  // Check for deleted keys
  for key, value1 in obj1.iterator2() {
    if !obj2.contains(key) {
      deleted[key] = value1
      score -= 30.0
    }
  }

  // Check for added keys
  for key, value2 in obj2.iterator2() {
    if !obj1.contains(key) {
      added[key] = value2
      score -= 30.0
    }
  }

  // Check for modified keys
  for key, value1 in obj1.iterator2() {
    if obj2.get(key) is Some(value2) {
      score += 20.0
      let { score: subscore, diff: change } = JsonDiff::diff_with_score(
        value1, value2, keys_only,
      )
      if change is Some(change_value) {
        diff[key] = change_value
      }
      score += (subscore / 5.0).clamp(-10.0, 20.0)
    }
  }
  if diff.is_empty() && deleted.is_empty() && added.is_empty() {
    JsonDiff::{
      score: 100.0 * @cmp.maximum(obj1.length().to_double(), 0.5),
      diff: None,
    }
  } else {
    let output = JsonEdit::Object(diff, deleted~, added~)
    JsonDiff::{ score: @cmp.maximum(score, 0.0), diff: Some(output) }
  }
}

///|
fn JsonDiff::check_type(item1 : Json, item2 : Json) -> Bool {
  match (item1, item2) {
    (Json::Null, Json::Null)
    | (Json::True, Json::True)
    | (Json::False, Json::False)
    | (Json::Number(_), Json::Number(_))
    | (Json::String(_), Json::String(_))
    | (Json::Array(_), Json::Array(_))
    | (Json::Object(_), Json::Object(_)) => true
    (_, _) => false
  }
}

///|
fn JsonDiff::find_matching_object(
  item : Json,
  index : Int,
  fuzzy_originals : Map[String, Json],
) -> BestMatch? {
  let mut best_match : BestMatch? = None
  let mut match_index = 0

  // rely on stable iter order
  for key, candidate in fuzzy_originals.iterator2() {
    let index_distance = match_index
      .reinterpret_as_uint()
      .sub(index.reinterpret_as_uint()) // wrapped sub
    if JsonDiff::check_type(item, candidate) {
      let { score, diff: _ } = JsonDiff::diff(item, candidate, keys_only=false)

      // choose higher score candidate
      // or closer candidate with same score
      let should_update = match best_match {
        Some(bm) =>
          score > bm.score ||
          (
            (score - bm.score).abs() < 2.2204460492503131e-16 &&
            index_distance < bm.index_distance
          )
        None => true
      }
      if should_update {
        best_match = Some(BestMatch::new(score, key, index_distance))
      }
    }
    match_index += 1
  }
  best_match
}

///|
fn JsonDiff::scalarize(
  counter : Ref[Int],
  array : Array[Json],
  scalar_values : Map[String, Json],
  originals : Map[String, Json],
  fuzzy_originals : Map[String, Json]?,
) -> Array[String] {
  let output_array = Array::new()
  for index, item in array.iterator2() {
    let mut value : String? = match item {
      Json::Object(_) => None
      _ => {
        let key = item.stringify()
        scalar_values.set(key, item)
        Some(key)
      }
    }
    if fuzzy_originals is Some(fuzzy_originals) &&
      JsonDiff::find_matching_object(item, index, fuzzy_originals)
      is Some(best_match) {
      if best_match.score > 40.0 && !originals.contains(best_match.key) {
        originals.set(best_match.key, item)
        value = Some(best_match.key)
      }
    }
    let final_value = match value {
      Some(v) => v
      None => {
        let proxy = "__$!SCALAR" + counter.val.to_string()
        counter.val += 1
        originals.set(proxy, item)
        proxy
      }
    }
    output_array.push(final_value)
  }
  output_array
}

///|
fn JsonDiff::is_scalarized(key : String, originals : Map[String, Json]) -> Bool {
  originals.contains(key)
}

///|
fn JsonDiff::get_scalar(
  key : String,
  scalar_values : Map[String, Json],
) -> Json {
  match scalar_values.get(key) {
    Some(value) => value
    None => abort("get_scarlar failed")
  }
}

///|
fn JsonDiff::descalarize(
  key : String,
  scalar_values : Map[String, Json],
  originals : Map[String, Json],
) -> Json {
  match originals.get(key) {
    Some(val) => val
    None => JsonDiff::get_scalar(key, scalar_values)
  }
}

///|
fn JsonDiff::array_diff(
  array1 : Array[Json],
  array2 : Array[Json],
  keys_only : Bool,
) -> JsonDiff {
  let counter = Ref::new(1)
  let originals1 = Map::new()
  let scalar_values1 = Map::new()
  let seq1 = JsonDiff::scalarize(
    counter,
    array1,
    scalar_values1,
    originals1,
    None,
  )
  let originals2 = Map::new()
  let scalar_values2 = Map::new()
  let seq2 = JsonDiff::scalarize(
    counter,
    array2,
    scalar_values2,
    originals2,
    Some(originals1),
  )
  let opcodes = SequenceMatcher::new(seq1, seq2).get_opcodes()
  let result = Array::new()
  let mut score = 0.0
  let mut all_equal = true
  for opcode in opcodes {
    if !(opcode.tag == Equal || (keys_only && opcode.tag == Replace)) {
      all_equal = false
    }
    match opcode.tag {
      Equal =>
        for i = opcode.first_start; i < opcode.first_end; i = i + 1 {
          let key = seq1[i]
          let is_scalarized1 = JsonDiff::is_scalarized(key, originals1)
          guard !is_scalarized1 || JsonDiff::is_scalarized(key, originals2) else {
            abort(
              "Internal bug: the items associated to the key \{key} are different in the two dictionaries",
            )
          }
          if is_scalarized1 {
            let item1 = JsonDiff::descalarize(key, scalar_values1, originals1)
            let item2 = JsonDiff::descalarize(key, scalar_values2, originals2)
            let { score: _, diff: change } = JsonDiff::diff(
              item1,
              item2,
              keys_only~,
            )
            if change is Some(change) {
              result.push(Some(Modification(change)))
              all_equal = false
            } else {
              result.push(None)
            }
          } else {
            result.push(
              Some(NoChange(JsonDiff::get_scalar(key, scalar_values1))),
            )
          }
          score += 10.0
        }
      Delete =>
        for i = opcode.first_start; i < opcode.first_end; i = i + 1 {
          let key = seq1[i]
          result.push(
            Some(Delete(JsonDiff::descalarize(key, scalar_values1, originals1))),
          )
          score -= 5.0
        }
      Insert =>
        for i = opcode.second_start; i < opcode.second_end; i = i + 1 {
          let key = seq2[i]
          result.push(
            Some(Insert(JsonDiff::descalarize(key, scalar_values2, originals2))),
          )
          score -= 5.0
        }
      Replace =>
        if keys_only {
          let min_len = @cmp.minimum(
            opcode.first_end - opcode.first_start,
            opcode.second_end - opcode.second_start,
          )
          for offset = 0; offset < min_len; offset = offset + 1 {
            let key1 = seq1[opcode.first_start + offset]
            let key2 = seq2[opcode.second_start + offset]
            let { score: _, diff: change } = JsonDiff::diff(
              JsonDiff::descalarize(key1, scalar_values1, originals1),
              JsonDiff::descalarize(key2, scalar_values2, originals2),
              keys_only~,
            )
            match change {
              Some(change) => {
                result.push(Some(Modification(change)))
                all_equal = false
              }
              None => result.push(None)
            }
          }
        } else {
          // Handle as delete then insert
          for i = opcode.first_start; i < opcode.first_end; i = i + 1 {
            let key = seq1[i]
            result.push(
              Some(
                Delete(JsonDiff::descalarize(key, scalar_values1, originals1)),
              ),
            )
            score -= 5.0
          }
          for i = opcode.second_start; i < opcode.second_end; i = i + 1 {
            let key = seq2[i]
            result.push(
              Some(
                Insert(JsonDiff::descalarize(key, scalar_values2, originals2)),
              ),
            )
            score -= 5.0
          }
        }
    }
  }
  if all_equal || opcodes.is_empty() {
    JsonDiff::{ score: 100.0, diff: None }
  } else {
    JsonDiff::{
      score: @cmp.maximum(score, 0.0),
      diff: Some(JsonEdit::Array(result)),
    }
  }
}

///|
fn JsonDiff::diff_with_score(
  json1 : Json,
  json2 : Json,
  keys_only : Bool,
) -> JsonDiff {
  match (json1, json2) {
    (Json::Object(lhs), Json::Object(rhs)) =>
      JsonDiff::object_diff(lhs, rhs, keys_only)
    (Json::Array(array1), Json::Array(array2)) =>
      JsonDiff::array_diff(array1, array2, keys_only)
    _ =>
      if !keys_only && json1 != json2 {
        JsonDiff::{ score: 0.0, diff: Some(Replace(old=json1, new=json2)) }
      } else {
        JsonDiff::{ score: 100.0, diff: None }
      }
  }
}

///|
fn Double::clamp(self : Double, min : Double, max : Double) -> Double {
  if self < min {
    return min
  }
  if self > max {
    return max
  }
  return self
}

///|
test {
  inspect((-3.0).clamp(-2.0, 1.0), content="-2")
  inspect(0.0.clamp(-2.0, 1.0), content="0")
  inspect(2.0.clamp(-2.0, 1.0), content="1")
  inspect(@double.not_a_number.clamp(-2.0, 1.0), content="NaN")
}
