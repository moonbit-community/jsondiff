///|
test "test scalar" {
  assert_eq(JsonDiff::diff(42, 42).diff, None)
  assert_eq(JsonDiff::diff("foo", "foo").diff, None)
  @json.inspect(JsonDiff::diff(42, 10).diff, content=[
    { "__old": 42, "__new": 10 },
  ])
}

///|
test "test objects" {
  assert_eq(JsonDiff::diff({}, {}, keys_only=false).diff, None)
  assert_eq(
    JsonDiff::diff({ "foo": 42, "bar": 10 }, { "foo": 42, "bar": 10 }).diff,
    None,
  )
  @json.inspect(
    JsonDiff::diff({ "foo": 42, "bar": { "bbbar": 10, "bbboz": 11 } }, {
      "foo": 42,
      "bar": { "bbbar": 12 },
    }).diff,
    content=[
      { "bar": { "bbboz__deleted": 11, "bbbar": { "__old": 10, "__new": 12 } } },
    ],
  )
}

///|
test "array of scalars" {
  assert_eq(JsonDiff::diff([10, 20, 30], [10, 20, 30]).diff, None)
  assert_eq(
    JsonDiff::diff([10, 20, 30], [10, 30]).diff.map(edit => edit.to_json()),
    Some([[" ", 10], ["-", 20], [" ", 30]]),
  )
  assert_eq(
    JsonDiff::diff([10, 30], [10, 20, 30]).diff.map(edit => edit.to_json()),
    Some([[" ", 10], ["+", 20], [" ", 30]]),
  )
  assert_eq(
    JsonDiff::diff([10, 20], [10, 20, 30]).diff.map(edit => edit.to_json()),
    Some([[" ", 10], [" ", 20], ["+", 30]]),
  )
}

///|
test "array of objects" {
  assert_eq(
    JsonDiff::diff([{ "foo": 10 }, { "foo": 20 }, { "foo": 30 }], [
      { "foo": 10 },
      { "foo": 20 },
      { "foo": 30 },
    ]).diff,
    None,
  )
  assert_eq(JsonDiff::diff([{}], [{}]).diff, None)
  assert_eq(JsonDiff::diff([[]], [[]]).diff, None)
  assert_eq(JsonDiff::diff([1, null, null], [1, null, null]).diff, None)
  assert_eq(
    JsonDiff::diff([{ "a": 1, "b": 2 }, { "a": 1, "b": 2 }], [
      { "a": 1, "b": 2 },
      { "a": 1, "b": 2 },
    ]).diff,
    None,
  )
  @json.inspect(
    JsonDiff::diff([{ "foo": 10 }, { "foo": 20 }, { "foo": 30 }], [
      { "foo": 10 },
      { "foo": 30 },
    ]).diff,
    content=[[[" "], ["-", { "foo": 20 }], [" "]]],
  )
  @json.inspect(
    JsonDiff::diff([{ "foo": 10 }, { "foo": 30 }], [
      { "foo": 10 },
      { "foo": 20 },
      { "foo": 30 },
    ]).diff,
    content=[[[" "], ["+", { "foo": 20 }], [" "]]],
  )
  @json.inspect(
    JsonDiff::diff([{ "name": "Foo", "a": 3, "b": 1 }, { "foo": 10 }], [
      { "name": "Foo", "a": 3, "b": 1 },
      { "name": "Foo", "a": 3, "b": 1, "c": 1 },
      { "foo": 10 },
    ]).diff,
    content=[[[" "], ["+", { "name": "Foo", "a": 3, "b": 1, "c": 1 }], [" "]]],
  )
  @json.inspect(
    JsonDiff::diff(
      [
        { "foo": 10, "bar": { "bbbar": 10, "bbboz": 11 } },
        { "foo": 20, "bar": { "bbbar": 50, "bbboz": 25 } },
        { "foo": 30, "bar": { "bbbar": 92, "bbboz": 34 } },
      ],
      [
        { "foo": 10, "bar": { "bbbar": 10, "bbboz": 11 } },
        { "foo": 21, "bar": { "bbbar": 50, "bbboz": 25 } },
        { "foo": 30, "bar": { "bbbar": 92, "bbboz": 34 } },
      ],
    ).diff,
    content=[[[" "], ["~", { "foo": { "__old": 20, "__new": 21 } }], [" "]]],
  )
}

///|
test "scalar keys" {
  assert_eq(JsonDiff::diff(42, 42, keys_only=true).diff, None)
  assert_eq(
    JsonDiff::diff(
      { "foo": 42, "bar": 10 },
      { "foo": 42, "bar": 10 },
      keys_only=true,
    ).diff,
    None,
  )
  assert_eq(
    JsonDiff::diff(
      { "foo": 42, "bar": { "bbbar": 10, "bbboz": 11 } },
      { "foo": 42, "bar": { "bbbar": 10, "bbboz": 11 } },
      keys_only=true,
    ).diff,
    None,
  )
  @json.inspect(
    JsonDiff::diff({ "foo": 42, "bar": 10 }, { "bar": 10 }, keys_only=true).diff,
    content=[{ "foo__deleted": 42 }],
  )
  @json.inspect(
    JsonDiff::diff({ "bar": 10 }, { "foo": 42, "bar": 10 }, keys_only=true).diff,
    content=[{ "foo__added": 42 }],
  )
  assert_eq(
    JsonDiff::diff({ "foo": 42 }, { "foo": 10 }, keys_only=true).diff,
    None,
  )
  assert_eq(
    JsonDiff::diff(
      { "foo": 42, "bar": { "bbbar": 10 } },
      { "foo": 42, "bar": { "bbbar": 12 } },
      keys_only=true,
    ).diff,
    None,
  )
  @json.inspect(
    JsonDiff::diff(
      { "foo": 42, "bar": { "bbbar": 10, "bbboz": 11 } },
      { "foo": 42, "bar": { "bbbar": 12 } },
      keys_only=true,
    ).diff,
    content=[{ "bar": { "bbboz__deleted": 11 } }],
  )
}

///|
test "array of scalar keys" {
  assert_eq(
    JsonDiff::diff([10, 20, 30], [10, 20, 30], keys_only=true).diff,
    None,
  )
  assert_eq(
    JsonDiff::diff([10, 20, 30], [10, 42, 30], keys_only=true).diff,
    None,
  )
  @json.inspect(JsonDiff::diff([10, 20, 30], [10, 30], keys_only=true).diff, content=[
    [[" ", 10], ["-", 20], [" ", 30]],
  ])
  @json.inspect(JsonDiff::diff([10, 30], [10, 20, 30], keys_only=true).diff, content=[
    [[" ", 10], ["+", 20], [" ", 30]],
  ])
  @json.inspect(JsonDiff::diff([10, 20], [10, 20, 30], keys_only=true).diff, content=[
    [[" ", 10], [" ", 20], ["+", 30]],
  ])
}

///|
test "array of object keys" {
  assert_eq(
    JsonDiff::diff(
      [{ "foo": 10, "foo": 20, "foo": 30 }],
      [{ "foo": 10, "foo": 20, "foo": 30 }],
      keys_only=true,
    ).diff,
    None,
  )
  assert_eq(JsonDiff::diff([{}], [{}], keys_only=true).diff, None)
  assert_eq(JsonDiff::diff([[]], [[]], keys_only=true).diff, None)
  assert_eq(
    JsonDiff::diff(
      [{ "a": 1, "b": 2 }, { "a": 1, "b": 2 }],
      [{ "a": 1, "b": 2 }, { "a": 1, "b": 2 }],
      keys_only=true,
    ).diff,
    None,
  )
  @json.inspect(
    JsonDiff::diff(
      [{ "foo": 10 }, { "foo": 30 }],
      [{ "foo": 10 }, { "foo": 20 }, { "foo": 30 }],
      keys_only=true,
    ).diff,
    content=[[[" "], ["+", { "foo": 20 }], [" "]]],
  )
  assert_eq(
    JsonDiff::diff(
      [
        { "foo": 10, "bar": { "bbbar": 10, "bbboz": 11 } },
        { "foo": 20, "bar": { "bbbar": 50, "bbboz": 25 } },
        { "foo": 30, "bar": { "bbbar": 92, "bbboz": 34 } },
      ],
      [
        { "foo": 10, "bar": { "bbbar": 10, "bbboz": 11 } },
        { "foo": 21, "bar": { "bbbar": 50, "bbboz": 25 } },
        { "foo": 30, "bar": { "bbbar": 92, "bbboz": 34 } },
      ],
      keys_only=true,
    ).diff,
    None,
  )
}
