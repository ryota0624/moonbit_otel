// SpanExporter trait: Spanを外部に出力するためのインターフェース

///|
pub(open) trait SpanExporter {
  // Spanのバッチをエクスポート
  async export_spans(Self, Array[Span]) -> Unit

  // Exporterをシャットダウン
  async shutdown(Self) -> Unit
  enable_batch_export(self : Self, options? : BatchExporterOptions) -> BatchExporter = _
}

///|
impl SpanExporter with enable_batch_export(
  self : Self,
  options? : BatchExporterOptions = Default::default(),
) -> BatchExporter {
  BatchExporter::new(self, options~)
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
  priv sending_queue : @async.Queue[Unit]
  priv schedule_queue : @async.Queue[Unit]
}

///|
pub impl Default for BatchExporterOptions with default() -> BatchExporterOptions {
  {
    max_queue_size: DefaultMaxQueueSize,
    schedule_delay_millis: DefaultScheduleDelay,
    export_timeout_millis: DefaultExportTimeout,
    max_export_batch_size: DefaultMaxExportBatchSize,
    set_timeout: async fn(duration, callback) {
      @async.sleep(duration)
      callback()
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
    sending_queue: @async.Queue::new(kind=@aqueue.Kind::Blocking(1)),
    schedule_queue: @async.Queue::new(kind=@aqueue.Kind::Unbounded),
  }
}

///|
pub async fn BatchExporter::start(self : BatchExporter) -> Unit {
  @async.with_task_group(fn(group) {
    group.spawn_loop(async fn() {
      self.schedule_queue.get()
      self.schedule_flush() catch {
        e =>
          (self.options.logger_factory)().log(
            "[BatchExporter] Failed to flush spans: " + e.to_string(),
          )
      }
      IterContinue
    })
  })
}
// DefaultMaxQueueSize is the maximum number of spans that can be queued for export.

///|
pub impl SpanExporter for BatchExporter with export_spans(
  self : BatchExporter,
  spans : Array[Span],
) -> Unit {
  self.export_waiting_spans.push_iter(spans.iter())
  self.schedule_queue.put(())
  // self.schedule_flush()
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
  self.sending_queue.put(())
  let count_of_sending = @cmp.minimum(
    self.export_waiting_spans.length(),
    self.options.max_export_batch_size,
  )
  let sending_spans = self.export_waiting_spans.drain(0, count_of_sending)
  self.exporter.export_spans(sending_spans)
  self.sending_queue.get()
  ()
}

///|
async fn BatchExporter::schedule_flush(self : BatchExporter) -> Unit {
  if self.export_waiting_spans.is_empty() {
    (self.options.logger_factory)().log(
      "[BatchExporter] No spans to export, skipping flush.",
    )
    return
  }
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
