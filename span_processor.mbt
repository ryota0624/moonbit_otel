///|
pub trait SpanProcessor {
  on_span_start(Self, span : Span) -> Unit noraise
  on_span_end(Self, span : Span) -> Unit noraise
  async shutdown(Self) -> Unit
  async force_flush(Self) -> Unit
}

///|
pub struct BatchSpanProcessorOptions {
  max_queue_size : Int
  schedule_delay_millis : Int
  export_timeout_millis : Int
  max_export_batch_size : Int
  set_timeout : async (Int, async () -> Unit noraise) -> Unit
  logger_factory : () -> InternalLogger
}

///|
pub struct BatchSpanProcessor {
  priv exporter : &SpanExporter
  priv options : BatchSpanProcessorOptions
  priv export_waiting_spans : Array[Span]
  priv sending_queue : @async.Queue[Unit]
  priv schedule_queue : @async.Queue[Unit]
}

///|
pub async fn[T, E : Error] suspend(
  f : ((T) -> Unit, (E) -> Unit) -> Unit,
) -> T raise E = "%async.suspend"

///|
pub impl Default for BatchSpanProcessorOptions with default() -> BatchSpanProcessorOptions {
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
pub fn BatchSpanProcessorOptions::enable_debug_log(
  self : BatchSpanProcessorOptions,
  print : (&Show) -> Unit,
) -> BatchSpanProcessorOptions {
  return BatchSpanProcessorOptions::{
    ..self,
    logger_factory: () => InternalLogger::{ print_fn: print },
  }
}

///|
pub fn BatchSpanProcessorOptions::with_max_queue_size(
  self : BatchSpanProcessorOptions,
  size : Int,
) -> BatchSpanProcessorOptions {
  { ..self, max_queue_size: size }
}

///|
pub fn BatchSpanProcessorOptions::with_schedule_delay_millis(
  self : BatchSpanProcessorOptions,
  millis : Int,
) -> BatchSpanProcessorOptions {
  { ..self, schedule_delay_millis: millis }
}

///|
pub fn BatchSpanProcessorOptions::with_export_timeout_millis(
  self : BatchSpanProcessorOptions,
  millis : Int,
) -> BatchSpanProcessorOptions {
  { ..self, export_timeout_millis: millis }
}

///|
pub fn BatchSpanProcessorOptions::with_max_export_batch_size(
  self : BatchSpanProcessorOptions,
  size : Int,
) -> BatchSpanProcessorOptions {
  { ..self, max_export_batch_size: size }
}

///|
pub fn BatchSpanProcessorOptions::with_set_timeout(
  self : BatchSpanProcessorOptions,
  set_timeout : async (Int, async () -> Unit noraise) -> Unit,
) -> BatchSpanProcessorOptions {
  { ..self, set_timeout, }
}

///|
pub fn BatchSpanProcessor::new(
  exporter : &SpanExporter,
  options? : BatchSpanProcessorOptions = BatchSpanProcessorOptions::default(),
) -> BatchSpanProcessor {
  {
    exporter,
    options,
    export_waiting_spans: [],
    sending_queue: @async.Queue::new(kind=@aqueue.Kind::Blocking(1)),
    schedule_queue: @async.Queue::new(kind=@aqueue.Kind::Unbounded),
  }
}

///|
pub async fn BatchSpanProcessor::start(self : BatchSpanProcessor) -> Unit {
  @async.with_task_group(async fn(group) {
    group.spawn_loop(async fn() {
      self.schedule_queue.get()
      self.schedule_flush() catch {
        e =>
          (self.options.logger_factory)().log(
            "[BatchSpanProcessor] Failed to flush spans: " + e.to_string(),
          )
      }
      IterContinue
    })
  })
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
pub impl SpanProcessor for BatchSpanProcessor with on_span_end(
  self : BatchSpanProcessor,
  span : Span,
) -> Unit {
  self.export_waiting_spans.push(span)
  run_async(async fn() noraise {
    self.schedule_queue.put(()) catch {
      e =>
        (self.options.logger_factory)().log(
          "[BatchSpanProcessor] Failed to schedule flush on span end: " +
          e.to_string(),
        )
    }
  })
}

///|
pub impl SpanProcessor for BatchSpanProcessor with on_span_start(
  _ : BatchSpanProcessor,
  _ : Span,
) -> Unit {

}

///|
pub impl SpanProcessor for BatchSpanProcessor with force_flush(
  self : BatchSpanProcessor,
) -> Unit {
  self.flush_until_spans_empty()
}

///|
pub impl SpanProcessor for BatchSpanProcessor with shutdown(
  self : BatchSpanProcessor,
) -> Unit {
  self.force_flush()
  self.exporter.shutdown()
}

///|
async fn BatchSpanProcessor::flush(self : BatchSpanProcessor) -> Unit {
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
async fn BatchSpanProcessor::flush_until_spans_empty(
  self : BatchSpanProcessor,
) -> Unit {
  while !self.export_waiting_spans.is_empty() {
    self.flush()
  }
}

///|
async fn BatchSpanProcessor::schedule_flush(self : BatchSpanProcessor) -> Unit {
  if self.export_waiting_spans.is_empty() {
    (self.options.logger_factory)().log(
      "[BatchSpanProcessor] No spans to export, skipping flush.",
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
            "[BatchSpanProcessor] Failed to flush spans: " + e.to_string(),
          )
      }
    })
  }
}
