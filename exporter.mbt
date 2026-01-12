// SpanExporter trait: Spanを外部に出力するためのインターフェース

///|
pub trait SpanExporter {
  // Spanのバッチをエクスポート
  async export_spans(Self, Array[Span]) -> Unit

  // Exporterをシャットダウン
  async shutdown(Self) -> Unit
}

// ConsoleExporter: Spanを指定された出力関数で出力

///|
pub struct PrettyPrintExporter {
  print_fn : (String) -> Unit // カスタム出力関数
}

///|
pub impl SpanExporter for PrettyPrintExporter with export_spans(
  self : PrettyPrintExporter,
  spans : Array[Span],
) -> Unit {
  self.export_spans(spans)
}

///|
pub impl SpanExporter for PrettyPrintExporter with shutdown(
  self : PrettyPrintExporter,
) -> Unit {
  self.shutdown()
}

// ConsoleExporterの作成

///|
pub fn PrettyPrintExporter::new(
  print : (String) -> Unit,
) -> PrettyPrintExporter {
  { print_fn: print }
}

// ConsoleExporterにSpanExporter traitを実装

///|
pub fn PrettyPrintExporter::export_spans(
  self : PrettyPrintExporter,
  spans : Array[Span],
) -> Unit {
  for span in spans {
    (self.print_fn)(format_span(span))
  }
}

///|
pub fn PrettyPrintExporter::shutdown(self : PrettyPrintExporter) -> Unit {
  (self.print_fn)("ConsoleExporter shutdown")
}

// Spanを人間が読みやすい形式にフォーマット

///|
fn format_span(span : Span) -> String {
  let mut output = "\n"
  output = output + "Span: " + span.name + "\n"
  output = output + "  TraceID: " + span.traceId.to_string() + "\n"
  output = output + "  SpanID: " + span.spanId.to_string() + "\n"

  // 親SpanIDの表示
  match span.parent_span_id {
    Some(parent_id) =>
      output = output + "  ParentSpanID: " + parent_id.to_string() + "\n"
    None => ()
  }
  output = output + "  Kind: " + span.kind.to_string() + "\n"
  output = output + "  Status: " + span.status.to_string() + "\n"
  output = output +
    "  StartTime: " +
    span.start_time_unix_nano.to_string() +
    "ns\n"

  // 期間の表示
  match span.duration() {
    Some(d) => output = output + "  Duration: " + d.to_string() + "ns\n"
    None => output = output + "  Duration: (not ended)\n"
  }

  // 属性の表示
  if not(span.attributes.is_empty()) {
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
  if not(span.links.is_empty()) {
    output = output + "  Links:\n"
    for link in span.links {
      output = output +
        "    TraceID: " +
        link.trace_id.to_string() +
        ", SpanID: " +
        link.span_id.to_string() +
        "\n"
      if not(link.attributes.is_empty()) {
        output = output + "      Attributes:\n"
        link.attributes.each(fn(key, value) {
          output = output +
            "        " +
            key +
            ": " +
            format_attribute_value(value) +
            "\n"
        })
      }
    }
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
      if not(event.attributes.is_empty()) {
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
  }
}

///|
pub struct BatchExporterOptions {
  max_queue_size : Int
  schedule_delay_millis : Int
  export_timeout_millis : Int
  max_export_batch_size : Int
  set_timeout : async (Int, async () -> Unit) -> Unit
}

///|
priv struct BatchExporter {
  exporter : &SpanExporter
  options : BatchExporterOptions
  export_waiting_spans : Array[Span]
  sending_ququeue : @async.Queue[Unit]
}

///|
impl Default for BatchExporterOptions with default() -> BatchExporterOptions {
  {
    max_queue_size: DefaultMaxQueueSize,
    schedule_delay_millis: DefaultScheduleDelay,
    export_timeout_millis: DefaultExportTimeout,
    max_export_batch_size: DefaultMaxExportBatchSize,
    set_timeout: async fn(delay, callback) {
      callback() catch {
        err =>
          // エラーハンドリング（必要に応じてログ出力など）
          ()
      }
    },
  }
}

///|
fn BatchExporter::new(
  exporter : &SpanExporter,
  options? : BatchExporterOptions,
) -> BatchExporter {
  let opts = match options {
    Some(o) => o
    None => BatchExporterOptions::default()
  }
  {
    exporter,
    options: opts,
    export_waiting_spans: [],
    sending_ququeue: @async.Queue::new(kind=@aqueue.Kind::Blocking(1)),
  }
}
// DefaultMaxQueueSize is the maximum number of spans that can be queued for export.

///|
const DefaultMaxQueueSize = 2048

// DefaultScheduleDelay is the delay interval between two consecutive exports, in milliseconds.

///|
const DefaultScheduleDelay = 5000
// DefaultExportTimeout is the duration after which an export is cancelled, in milliseconds.

///|
const DefaultExportTimeout = 30000

///|
const DefaultMaxExportBatchSize = 512

///|
impl SpanExporter for BatchExporter with export_spans(
  self : BatchExporter,
  spans : Array[Span],
) -> Unit {
  self.export_waiting_spans.push_iter(spans.iter())
  self.schedule_flush()
}

///|
impl SpanExporter for BatchExporter with shutdown(self : BatchExporter) -> Unit {
  self.shutdown()
}

///|
async fn BatchExporter::shutdown(self : BatchExporter) -> Unit {
  self.flush()
  self.exporter.shutdown()
}

///|
async fn BatchExporter::flush(self : BatchExporter) -> Unit {
  self.sending_ququeue.put(())
  let count_of_sending = @cmp.minimum(
    self.export_waiting_spans.length(),
    self.options.max_export_batch_size,
  )
  let sending_spans = self.export_waiting_spans[0:count_of_sending]
  self.exporter.export_spans(sending_spans.to_array())
  self.sending_ququeue.get()
  ()
}

///|
async fn BatchExporter::schedule_flush(self : BatchExporter) -> Unit {
  if self.export_waiting_spans.length() >= self.options.max_export_batch_size {
    self.flush()
  } else {
    (self.options.set_timeout)(self.options.schedule_delay_millis, async fn() {
      self.flush()
    })
  }
}
