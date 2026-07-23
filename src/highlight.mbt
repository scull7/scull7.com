// Lightweight code highlighter for sample buffers (Item 3).
// String indexing yields UInt16 code units.

fn hl_is_alpha(c : UInt16) -> Bool {
  (c >= ('a' : UInt16) && c <= ('z' : UInt16)) ||
  (c >= ('A' : UInt16) && c <= ('Z' : UInt16)) ||
  c == ('_' : UInt16)
}

fn hl_is_digit(c : UInt16) -> Bool {
  c >= ('0' : UInt16) && c <= ('9' : UInt16)
}

fn hl_is_alnum(c : UInt16) -> Bool {
  hl_is_alpha(c) || hl_is_digit(c)
}

fn hl_is_kw(word : String) -> Bool {
  match word {
    "fn"
    | "let"
    | "mut"
    | "use"
    | "pub"
    | "async"
    | "await"
    | "return"
    | "open"
    | "in"
    | "if"
    | "else"
    | "match"
    | "struct"
    | "impl"
    | "trait"
    | "const"
    | "type"
    | "mod"
    | "crate"
    | "self"
    | "Self"
    | "true"
    | "false"
    | "and"
    | "or"
    | "not"
    | "as"
    | "for"
    | "while"
    | "loop"
    | "break"
    | "continue"
    | "where"
    | "move"
    | "ref"
    | "static"
    | "unsafe"
    | "extern"
    | "super"
    | "dyn"
    | "box" => true
    _ => false
  }
}

fn hl_is_ty_word(word : String) -> Bool {
  match word {
    "Ok"
    | "Err"
    | "Some"
    | "None"
    | "Result"
    | "Option"
    | "String"
    | "str"
    | "bool"
    | "u8"
    | "u16"
    | "u32"
    | "u64"
    | "i8"
    | "i16"
    | "i32"
    | "i64"
    | "usize"
    | "isize"
    | "f32"
    | "f64"
    | "char"
    | "Vec"
    | "Box"
    | "Self"
    | "Cents"
    | "Event"
    | "EventBus"
    | "GpuFleet"
    | "Ack"
    | "Decode"
    | "BsResult" => true
    _ => {
      if word.length() == 0 {
        false
      } else {
        let c = word[0]
        c >= ('A' : UInt16) && c <= ('Z' : UInt16)
      }
    }
  }
}

fn hl_span(cls : String, text : String) -> @dom.DomNode {
  if cls.is_empty() {
    @dom.text(text)
  } else {
    @dom.span(class=cls) <| [@dom.text(text)]
  }
}

fn hl_slice(src : String, start : Int, end_ : Int) -> String {
  src[start:end_].to_owned()
}

///|
/// Tokenize sample source into colored DOM spans for `.code-block`.
fn highlight_code(src : String) -> Array[@dom.DomNode] {
  let n = src.length()
  let out : Array[@dom.DomNode] = []
  let mut i = 0
  while i < n {
    let c = src[i]

    // line comment //
    if c == ('/' : UInt16) && i + 1 < n && src[i + 1] == ('/' : UInt16) {
      let start = i
      i = i + 2
      while i < n && src[i] != ('\n' : UInt16) {
        i = i + 1
      }
      out.push(hl_span("cm", hl_slice(src, start, i)))
      continue
    }

    // block comment (* *)
    if c == ('(' : UInt16) && i + 1 < n && src[i + 1] == ('*' : UInt16) {
      let start = i
      i = i + 2
      while i + 1 < n &&
        !(src[i] == ('*' : UInt16) && src[i + 1] == (')' : UInt16)) {
        i = i + 1
      }
      if i + 1 < n {
        i = i + 2
      }
      out.push(hl_span("cm", hl_slice(src, start, i)))
      continue
    }

    // string
    if c == ('"' : UInt16) {
      let start = i
      i = i + 1
      while i < n {
        if src[i] == ('\\' : UInt16) && i + 1 < n {
          i = i + 2
          continue
        }
        if src[i] == ('"' : UInt16) {
          i = i + 1
          break
        }
        i = i + 1
      }
      out.push(hl_span("st", hl_slice(src, start, i)))
      continue
    }

    // number
    if hl_is_digit(c) {
      let start = i
      i = i + 1
      while i < n &&
        (hl_is_digit(src[i]) || src[i] == ('.' : UInt16) ||
        src[i] == ('_' : UInt16)) {
        i = i + 1
      }
      out.push(hl_span("nu", hl_slice(src, start, i)))
      continue
    }

    // identifier
    if hl_is_alpha(c) {
      let start = i
      i = i + 1
      while i < n && hl_is_alnum(src[i]) {
        i = i + 1
      }
      let word = hl_slice(src, start, i)
      let mut cls = ""
      if hl_is_kw(word) {
        cls = "kw"
      } else if hl_is_ty_word(word) {
        cls = "ty"
      } else {
        let mut j = i
        while j < n &&
          (src[j] == (' ' : UInt16) || src[j] == ('\t' : UInt16)) {
          j = j + 1
        }
        if j < n && src[j] == ('(' : UInt16) {
          cls = "fn"
        }
      }
      out.push(hl_span(cls, word))
      continue
    }

    // plain run
    let start = i
    i = i + 1
    while i < n {
      let d = src[i]
      if d == ('/' : UInt16) || d == ('(' : UInt16) || d == ('"' : UInt16) ||
        hl_is_digit(d) || hl_is_alpha(d) {
        break
      }
      i = i + 1
    }
    out.push(hl_span("", hl_slice(src, start, i)))
  }
  out
}
