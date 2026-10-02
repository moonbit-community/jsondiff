///|
enum JsonEdit {
  Object(
    Map[String, JsonEdit],
    added~ : Map[String, Json],
    deleted~ : Map[String, Json]
  )
  Array(Array[JsonArrayEdit?])
  Replace(old~ : Json, new~ : Json)
} derive(Debug, Eq)

///|
#deprecated("`JsonEdit` is internal to jsondiff")
pub extend JsonEdit with @debug.Debug::{to_repr}

///|
#deprecated("`JsonEdit` is internal to jsondiff")
pub extend JsonEdit with Eq::{not_equal, equal}

///|
enum JsonArrayEdit {
  Modification(JsonEdit)
  NoChange(Json)
  Delete(Json)
  Insert(Json)
} derive(Debug, Eq)

///|
#deprecated("`JsonArrayEdit` is internal to jsondiff")
pub extend JsonArrayEdit with @debug.Debug::{to_repr}

///|
#deprecated("`JsonArrayEdit` is internal to jsondiff")
pub extend JsonArrayEdit with Eq::{not_equal, equal}

///|
impl ToJson for JsonEdit with fn to_json(self) {
  match self {
    Object(object, added~, deleted~) => {
      let result = Map([])
      for key, value in deleted.iter2() {
        result[key + "__deleted"] = value
      }
      for key, value in added.iter2() {
        result[key + "__added"] = value
      }
      for key, value in object.iter2() {
        result[key] = ToJson::to_json(value)
      }
      return Json::object(result)
    }
    Array(arr) => {
      let result = []
      for arr_edit in arr {
        let arr_edit = match arr_edit {
          None => Json::array([" "])
          Some(Modification(change)) => Json::array(["~", change])
          Some(NoChange(json)) => Json::array([" ", json])
          Some(Delete(json)) => Json::array(["-", json])
          Some(Insert(json)) => Json::array(["+", json])
        }
        result.push(arr_edit)
      }
      return Json::array(result)
    }
    Replace(old~, new~) => { "__old": old, "__new": new }
  }
}
