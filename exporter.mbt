// SpanExporter trait: Spanを外部に出力するためのインターフェース

///|
pub trait SpanExporter {
  // Spanのバッチをエクスポート
  export_spans(Self, Array[Span]) -> Unit

  // Exporterをシャットダウン
  shutdown(Self) -> Unit
}

// ConsoleExporter: 標準出力にSpanを出力

///|
pub struct ConsoleExporter {
  prefix : String // 出力時のプレフィックス
}

// ConsoleExporterの作成

///|
pub fn ConsoleExporter::new() -> ConsoleExporter {
  { prefix: "[OpenTelemetry]" }
}

// ConsoleExporterにSpanExporter traitを実装

///|
pub fn ConsoleExporter::export_spans(
  self : ConsoleExporter,
  spans : Array[Span],
) -> Unit {
  for span in spans {
    println(self.prefix + " " + format_span(span))
  }
}

///|
pub fn ConsoleExporter::shutdown(self : ConsoleExporter) -> Unit {
  println(self.prefix + " ConsoleExporter shutdown")
}

// Spanを人間が読みやすい形式にフォーマット

///|
fn format_span(span : Span) -> String {
  let mut output = "\n"
  output = output + "Span: " + span.name + "\n"
  output = output + "  TraceID: " + span.context.trace_id.to_string() + "\n"
  output = output + "  SpanID: " + span.context.span_id.to_string() + "\n"

  // 親SpanIDの表示
  match span.parent_span_id {
    Some(parent_id) =>
      output = output + "  ParentSpanID: " + parent_id.to_string() + "\n"
    None => ()
  }
  output = output + "  Kind: " + span.kind.to_string() + "\n"
  output = output + "  Status: " + span.status.to_string() + "\n"
  output = output + "  StartTime: " + span.start_time.to_string() + "ns\n"

  // 期間の表示
  match span.duration() {
    Some(d) => output = output + "  Duration: " + d.to_string() + "ns\n"
    None => output = output + "  Duration: (not ended)\n"
  }

  // 属性の表示
  if span.attributes.length() > 0 {
    output = output + "  Attributes:\n"
    span.attributes.each(fn(key, value) {
      output = output +
        "    " +
        key +
        ": " +
        format_attribute_value(value) +
        "\n"
    })
  }

  // イベントの表示
  if span.events.length() > 0 {
    output = output + "  Events:\n"
    for event in span.events {
      output = output +
        "    " +
        event.name +
        " @ " +
        event.timestamp.to_string() +
        "ns\n"
      if event.attributes.length() > 0 {
        event.attributes.each(fn(key, value) {
          output = output +
            "      " +
            key +
            ": " +
            format_attribute_value(value) +
            "\n"
        })
      }
    }
  }
  output
}

// AttributeValueを文字列にフォーマット

///|
fn format_attribute_value(value : AttributeValue) -> String {
  match value {
    AttributeValue::String(s) => "\"" + s + "\""
    AttributeValue::Int(i) => i.to_string()
    AttributeValue::Bool(b) => b.to_string()
    AttributeValue::Double(d) => d.to_string()
    AttributeValue::StringArray(arr) => {
      let mut result = "["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ", "
        }
        result = result + "\"" + arr[i] + "\""
      }
      result + "]"
    }
    AttributeValue::IntArray(arr) => {
      let mut result = "["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ", "
        }
        result = result + arr[i].to_string()
      }
      result + "]"
    }
    AttributeValue::BoolArray(arr) => {
      let mut result = "["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ", "
        }
        result = result + arr[i].to_string()
      }
      result + "]"
    }
    AttributeValue::DoubleArray(arr) => {
      let mut result = "["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ", "
        }
        result = result + arr[i].to_string()
      }
      result + "]"
    }
  }
}
