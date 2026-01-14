// SpanExporter trait: Spanを外部に出力するためのインターフェース

///|
pub(open) trait SpanExporter {
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
  set_timeout : async (Int, async () -> Unit noraise) -> Unit
  logger_factory : () -> InternalLogger
}

///|
pub struct BatchExporter {
  priv exporter : &SpanExporter
  priv options : BatchExporterOptions
  priv export_waiting_spans : Array[Span]
  priv sending_ququeue : @async.Queue[Unit]
}

///|
pub async fn[T, E : Error] suspend(
  f : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
#cfg(target="js")
#external
priv type JSTimer

///|
#cfg(target="js")
extern "js" fn js_set_timeout(f : () -> Unit, duration~ : Int) -> JSTimer =
  #| (f, duration) => setTimeout(f, duration)

///|
#cfg(target="js")
pub async fn sleep(duration : Int) -> Unit {
  suspend(fn(resume_ok, _resume_err) {
    js_set_timeout(duration~, fn() { resume_ok(()) }) |> ignore
  })
}

///|
#cfg(target="native")
pub async fn sleep(duration : Int) -> Unit {
  @async.sleep(duration)
}

///|
pub impl Default for BatchExporterOptions with default() -> BatchExporterOptions {
  {
    max_queue_size: DefaultMaxQueueSize,
    schedule_delay_millis: DefaultScheduleDelay,
    export_timeout_millis: DefaultExportTimeout,
    max_export_batch_size: DefaultMaxExportBatchSize,
    set_timeout: async fn(duration, callback) {
      sleep(duration)
      callback() catch {
        _ =>
          // エラーハンドリング（必要に応じてログ出力など）
          ()
      }
    },
    logger_factory: () => InternalLogger::none(),
  }
}

///|
pub fn BatchExporterOptions::enable_debug_log(
  self : BatchExporterOptions,
  print : (&Show) -> Unit,
) -> BatchExporterOptions {
  return BatchExporterOptions::{
    ..self,
    logger_factory: () => InternalLogger::{ print_fn: print },
  }
}

///|
pub fn BatchExporterOptions::with_max_queue_size(
  self : BatchExporterOptions,
  size : Int,
) -> BatchExporterOptions {
  { ..self, max_queue_size: size }
}

///|
pub fn BatchExporterOptions::with_schedule_delay_millis(
  self : BatchExporterOptions,
  millis : Int,
) -> BatchExporterOptions {
  { ..self, schedule_delay_millis: millis }
}

///|
pub fn BatchExporterOptions::with_export_timeout_millis(
  self : BatchExporterOptions,
  millis : Int,
) -> BatchExporterOptions {
  { ..self, export_timeout_millis: millis }
}

///|
pub fn BatchExporterOptions::with_max_export_batch_size(
  self : BatchExporterOptions,
  size : Int,
) -> BatchExporterOptions {
  { ..self, max_export_batch_size: size }
}

///|
pub fn BatchExporterOptions::with_set_timeout(
  self : BatchExporterOptions,
  set_timeout : async (Int, async () -> Unit noraise) -> Unit,
) -> BatchExporterOptions {
  { ..self, set_timeout, }
}

///|
pub fn BatchExporter::new(
  exporter : &SpanExporter,
  options? : BatchExporterOptions = BatchExporterOptions::default(),
) -> BatchExporter {
  {
    exporter,
    options,
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
pub impl SpanExporter for BatchExporter with export_spans(
  self : BatchExporter,
  spans : Array[Span],
) -> Unit {
  self.export_waiting_spans.push_iter(spans.iter())
  self.schedule_flush()
}

///|
pub impl SpanExporter for BatchExporter with shutdown(self : BatchExporter) -> Unit {
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
    (self.options.set_timeout)(self.options.schedule_delay_millis, async fn() -> Unit noraise {
      self.flush() catch {
        e =>
          (self.options.logger_factory)().log(
            "[BatchExporter] Failed to flush spans: " + e.to_string(),
          )
      }
    })
  }
}
