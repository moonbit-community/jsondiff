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
  lhs : Json,
  rhs : Json,
  keys_only? : Bool = false,
) -> JsonDiff {
  JsonDiff::diff_with_score(lhs, rhs, keys_only)
}

///|
/// Finds the JSON structural difference of two JSON files and
/// returns it as a formatted string.
pub fn JsonDiff::diff_string(
  lhs : Json,
  rhs : Json,
  keys_only? : Bool = false,
  terminal? : Bool = false,
) -> String? {
  let jsondiff = JsonDiff::diff(lhs, rhs, keys_only~)
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
  lhs : Map[String, Json],
  rhs : Map[String, Json],
  keys_only : Bool,
) -> JsonDiff {
  let diff = Map([])
  let deleted = Map([])
  let added = Map([])
  let mut score = 0.0

  // Check for deleted keys
  for key, value in lhs.iter2() {
    if !rhs.contains(key) {
      deleted[key] = value
      score -= 30.0
    }
  }

  // Check for added keys
  for key, value in rhs.iter2() {
    if !lhs.contains(key) {
      added[key] = value
      score -= 30.0
    }
  }

  // Check for modified keys
  for key, value in lhs.iter2() {
    if rhs.get(key) is Some(rhs_value) {
      score += 20.0
      let { score: subscore, diff: change } = JsonDiff::diff_with_score(
        value, rhs_value, keys_only,
      )
      if change is Some(change_value) {
        diff[key] = change_value
      }
      score += (subscore / 5.0).clamp(min=-10.0, max=20.0)
    }
  }
  if diff.is_empty() && deleted.is_empty() && added.is_empty() {
    JsonDiff::{
      score: 100.0 * @cmp.maximum(lhs.length().to_double(), 0.5),
      diff: None,
    }
  } else {
    let output = JsonEdit::Object(diff, deleted~, added~)
    JsonDiff::{ score: @cmp.maximum(score, 0.0), diff: Some(output) }
  }
}

///|
fn JsonDiff::check_type(lhs : Json, rhs : Json) -> Bool {
  match (lhs, rhs) {
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
  for key, candidate in fuzzy_originals.iter2() {
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
  for index, item in array.iter2() {
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
  lhs : Array[Json],
  rhs : Array[Json],
  keys_only : Bool,
) -> JsonDiff {
  let counter = Ref(1)
  let lhs_originals = Map([])
  let lhs_scalar_values = Map([])
  let lhs_seq = JsonDiff::scalarize(
    counter,
    lhs,
    lhs_scalar_values,
    lhs_originals,
    None,
  )
  let rhs_originals = Map([])
  let rhs_scalar_values = Map([])
  let rhs_seq = JsonDiff::scalarize(
    counter,
    rhs,
    rhs_scalar_values,
    rhs_originals,
    Some(lhs_originals),
  )
  let opcodes = SequenceMatcher::new(lhs_seq, rhs_seq).get_opcodes()
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
          let key = lhs_seq[i]
          let lhs_is_scalarized = JsonDiff::is_scalarized(key, lhs_originals)
          guard !lhs_is_scalarized ||
            JsonDiff::is_scalarized(key, rhs_originals) else {
            abort(
              "Internal bug: the items associated to the key \{key} are different in the two dictionaries",
            )
          }
          if lhs_is_scalarized {
            let lhs_item = JsonDiff::descalarize(
              key, lhs_scalar_values, lhs_originals,
            )
            let rhs_item = JsonDiff::descalarize(
              key, rhs_scalar_values, rhs_originals,
            )
            let { score: _, diff: change } = JsonDiff::diff(
              lhs_item,
              rhs_item,
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
              Some(NoChange(JsonDiff::get_scalar(key, lhs_scalar_values))),
            )
          }
          score += 10.0
        }
      Delete =>
        for i = opcode.first_start; i < opcode.first_end; i = i + 1 {
          let key = lhs_seq[i]
          result.push(
            Some(
              Delete(
                JsonDiff::descalarize(key, lhs_scalar_values, lhs_originals),
              ),
            ),
          )
          score -= 5.0
        }
      Insert =>
        for i = opcode.second_start; i < opcode.second_end; i = i + 1 {
          let key = rhs_seq[i]
          result.push(
            Some(
              Insert(
                JsonDiff::descalarize(key, rhs_scalar_values, rhs_originals),
              ),
            ),
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
            let lhs_key = lhs_seq[opcode.first_start + offset]
            let rhs_key = rhs_seq[opcode.second_start + offset]
            let { score: _, diff: change } = JsonDiff::diff(
              JsonDiff::descalarize(lhs_key, lhs_scalar_values, lhs_originals),
              JsonDiff::descalarize(rhs_key, rhs_scalar_values, rhs_originals),
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
            let key = lhs_seq[i]
            result.push(
              Some(
                Delete(
                  JsonDiff::descalarize(key, lhs_scalar_values, lhs_originals),
                ),
              ),
            )
            score -= 5.0
          }
          for i = opcode.second_start; i < opcode.second_end; i = i + 1 {
            let key = rhs_seq[i]
            result.push(
              Some(
                Insert(
                  JsonDiff::descalarize(key, rhs_scalar_values, rhs_originals),
                ),
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
  lhs : Json,
  rhs : Json,
  keys_only : Bool,
) -> JsonDiff {
  match (lhs, rhs) {
    (Json::Object(lhs), Json::Object(rhs)) =>
      JsonDiff::object_diff(lhs, rhs, keys_only)
    (Json::Array(lhs), Json::Array(rhs)) =>
      JsonDiff::array_diff(lhs, rhs, keys_only)
    _ =>
      if !keys_only && lhs != rhs {
        JsonDiff::{ score: 0.0, diff: Some(Replace(old=lhs, new=rhs)) }
      } else {
        JsonDiff::{ score: 100.0, diff: None }
      }
  }
}
