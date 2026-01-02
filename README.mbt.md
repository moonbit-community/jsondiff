# jsondiff

Simple Json Structrual Diff Library

```mbt test
let old : Json = {
    "foo": [1, 2, 3],
    "bar": { "baz": "qux" }
}

let new : Json = {
    "foo": [1, 2, 4],
    "bar": { "baz": "quux" },
    "new_key": true
}
inspect(JsonDiff::diff_string(old, new).unwrap(), content=(
  #| {
  #|+  new_key: true
  #|   foo: [
  #|     1
  #|     2
  #|-    3
  #|+    4
  #|   ]
  #|   bar: {
  #|-    baz: "qux"
  #|+    baz: "quux"
  #|   }
  #| }
))
```