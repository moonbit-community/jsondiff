///|
fn JsonEdit::stringify(self : JsonEdit, terminal~ : Bool) -> String {
  output_colorful_text_for_terminal.val = terminal
  let output = Array::new()
  substringify(None, self, output, " ", 0)
  return output.join("\n")
}

///|
fn json_substringify(
  key : String?,
  json : Json,
  output : Array[String],
  tag : String,
  indent : Int,
) -> Unit {
  let prefix = if key is Some(key) { "\{key}: " } else { "" }
  let subindent = indent + 2
  match json {
    Object(object) => {
      output.push_line(tag, "\{String::make(indent, ' ')}\{prefix}{")
      for subkey, subvalue in object.iterator2() {
        json_substringify(Some(subkey), subvalue, output, tag, subindent)
      }
      output.push_line(tag, "\{String::make(indent, ' ')}}")
    }
    Array(arr) => {
      output.push_line(tag, "\{String::make(indent, ' ')}\{prefix}[")
      for subvalue in arr {
        json_substringify(None, subvalue, output, tag, subindent)
      }
      output.push_line(tag, "\{String::make(indent, ' ')}]")
    }
    json =>
      output.push_line(
        tag,
        String::make(indent, ' ') + prefix + json.stringify(),
      )
  }
}

///|
fn substringify(
  key : String?,
  jsonedit : JsonEdit,
  output : Array[String],
  tag : String,
  indent : Int,
) -> Unit {
  let prefix = if key is Some(key) { "\{key}: " } else { "" }
  let subindent = indent + 2
  match jsonedit {
    Replace(old~, new~) => {
      json_substringify(key, old, output, "-", indent)
      json_substringify(key, new, output, "+", indent)
    }
    Array(edits) => {
      output.push_line(tag, "\{String::make(indent, ' ')}\{prefix}[")
      for edit in edits {
        match edit {
          None => output.push_line(tag, "\{String::make(subindent, ' ')}...")
          Some(Modification(change)) =>
            substringify(None, change, output, " ", subindent)
          Some(NoChange(json)) =>
            json_substringify(None, json, output, " ", subindent)
          Some(Delete(json)) =>
            json_substringify(None, json, output, "-", subindent)
          Some(Insert(json)) =>
            json_substringify(None, json, output, "+", subindent)
        }
      }
      output.push_line(tag, "\{String::make(indent, ' ')}]")
    }
    Object(diff, added~, deleted~) => {
      output.push_line(tag, "\{String::make(indent, ' ')}\{prefix}{")
      for key, value in deleted.iterator2() {
        json_substringify(Some(key), value, output, "-", subindent)
      }
      for key, value in added.iterator2() {
        json_substringify(Some(key), value, output, "+", subindent)
      }
      for key, value in diff.iterator2() {
        substringify(Some(key), value, output, " ", subindent)
      }
      output.push_line(tag, "\{String::make(indent, ' ')}}")
    }
  }
}

///|
let output_colorful_text_for_terminal : Ref[Bool] = Ref::new(false)

///|
fn Array::push_line(self : Array[String], tag : String, line : String) -> Unit {
  let tagged_line = "\{tag}\{line}"
  if output_colorful_text_for_terminal.val {
    match tag {
      "+" =>
        // green
        self.push("\u{1b}[32m\{tag}\{line}\u{1b}[0m")
      "-" =>
        // red
        self.push("\u{1b}[31m\{tag}\{line}\u{1b}[0m")
      _ => self.push(tagged_line)
    }
  } else {
    self.push(tagged_line)
  }
}
