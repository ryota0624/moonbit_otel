// Tests for BatchExporter export_spans behavior
// These tests verify the batching and delayed export functionality

// Mock SpanExporter for testing

///|
struct MockExporter {
  export_calls : Array[Array[Span]]
  mut shutdown_called : Bool
}

///|
fn MockExporter::new() -> MockExporter {
  { export_calls: [], shutdown_called: false }
}

///|
pub fn MockExporter::export_spans(
  self : MockExporter,
  spans : Array[Span],
) -> Unit {
  self.export_calls.push(spans)
}

///|
pub fn MockExporter::shutdown(self : MockExporter) -> Unit {
  self.shutdown_called = true
}

///|
pub impl SpanExporter for MockExporter with export_spans(
  self : MockExporter,
  spans : Array[Span],
) -> Unit {
  self.export_spans(spans)
}

///|
pub impl SpanExporter for MockExporter with shutdown(self : MockExporter) -> Unit {
  self.shutdown()
}

// Helper function to create test spans

///|
fn create_export_test_span(name : String) -> Span {
  let trace_id = TraceID::new("0123456789abcdef0123456789abcdef")
  let span_id = SpanID::new("0123456789abcdef")
  let context = SpanContext::new(
    trace_id,
    span_id,
    TraceFlags::sampled(),
    false,
  )
  let resource = Resource::empty().with_string("service.name", "test-service")
  let tracer_id = TracerIdentifier::new("test-tracer", "1.0.0")
  Span::new(
    context,
    name,
    SpanKind::Internal,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
}

// Test: Batch size of 2 - immediate flush when reached

///|
async test "batch size of 2 triggers immediate flush when reached" {
  let mock = MockExporter::new()
  let mock_ref : &SpanExporter = mock as &SpanExporter
  let base_options : BatchExporterOptions = Default::default()
  let options = base_options
    .with_max_export_batch_size(2)
    .with_schedule_delay_millis(1000)
  let batch_exporter = BatchExporter::new(mock_ref, options~)
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      let span = create_export_test_span("test-span-1")
      let span2 = create_export_test_span("test-span-2")
      batch_exporter.export_spans([span, span2]) catch {
        _ => ()
      }
    })
    @async.sleep(10) // Allow async export to complete
    assert_eq(mock.export_calls.length(), 1)
    assert_eq(mock.export_calls[0].length(), 2)
  })
}

// Test: Batch size of 10 - delayed flush when not reached

///|
async test "batch size of 10 schedules delayed flush when not reached" {
  let mock = MockExporter::new()
  let mock_ref : &SpanExporter = mock as &SpanExporter
  let base_options : BatchExporterOptions = Default::default()
  let options = base_options
    .with_max_export_batch_size(10)
    .with_schedule_delay_millis(1000)
  let batch_exporter : &SpanExporter = BatchExporter::new(mock_ref, options~)
  @async.with_task_group(async fn(group) {
    group.spawn_bg(async fn() {
      let span = create_export_test_span("test-span-1")
      batch_exporter.export_spans([span]) catch {
        _ => ()
      }
    })
    @async.sleep(10) // Allow async timeout to be scheduled
    assert_true(mock.export_calls.is_empty())
    @async.sleep(1000)
    assert_false(mock.export_calls.is_empty())
  })

  // With batch size 10 and exporting less than 10 spans, timeout should be scheduled
  // This validates the delayed flush mechanism
}
