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
enum JsonArrayEdit {
  Modification(JsonEdit)
  NoChange(Json)
  Delete(Json)
  Insert(Json)
} derive(Debug, Eq)

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
        result[key] = value.to_json()
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
