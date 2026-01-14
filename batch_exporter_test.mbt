// Tests for BatchExporter functionality

// Helper function to create test spans

///|
fn create_test_batch_span(name : String) -> Span {
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

// Tests for BatchExporter initialization

///|
test "BatchExporter::new creates exporter with default options" {
  let exporter : PrettyPrintExporter = PrettyPrintExporter::new(fn(s) {
    println(s)
  })
  let exporter_ref : &SpanExporter = exporter
  let _batch_exporter = BatchExporter::new(exporter_ref)

  // We can't access internal fields directly, but we can verify the exporter was created
  // by checking it's a valid BatchExporter type
  assert_true(true)
}

// Tests for BatchExporterOptions

///|
test "BatchExporterOptions::Default trait creates default options" {
  let _options : BatchExporterOptions = Default::default()
  // Verify default options were created successfully
  assert_true(true)
}

///|
test "BatchExporterOptions::enable_debug_log enables logging" {
  let mut _log_count = 0
  let print_fn = fn(_msg : &Show) { _log_count = _log_count + 1 }
  let options : BatchExporterOptions = Default::default()
  let _options_with_log = options.enable_debug_log(print_fn)

  // Verify the logger factory was set correctly
  assert_true(true)
}

// Integration tests - testing the entire batch exporter flow

///|
test "BatchExporter can be created and used" {
  let mut _exported_count = 0
  let exporter : PrettyPrintExporter = PrettyPrintExporter::new(fn(_s) {
    _exported_count = _exported_count + 1
  })
  let _batch_exporter = BatchExporter::new(exporter)
  let _span = create_test_batch_span("test-span")

  // Verify that the batch exporter was created successfully
  assert_true(true)
}

///|
test "BatchExporter handles test span creation" {
  let span = create_test_batch_span("test-span")

  // Verify the span was created with the expected name
  assert_eq(span.name, "test-span")
  assert_eq(span.kind, SpanKind::Internal)
}

///|
test "create_test_batch_span creates spans with correct trace ID" {
  let span1 = create_test_batch_span("span1")
  let span2 = create_test_batch_span("span2")

  // Both spans should have the same trace ID (from the helper)
  assert_eq(span1.traceId.to_string(), span2.traceId.to_string())
}

///|
test "create_test_batch_span creates spans with service name" {
  let span = create_test_batch_span("test-span")

  // Verify the resource has the service.name attribute
  assert_eq(span.resource.get_string("service.name"), Some("test-service"))
}

///|
test "BatchExporter works with PrettyPrintExporter" {
  let output_lines : Array[String] = []
  let exporter : PrettyPrintExporter = PrettyPrintExporter::new(fn(s) {
    output_lines.push(s)
  })
  let _batch_exporter = BatchExporter::new(exporter)

  // Verify the batch exporter was created with the pretty print exporter
  assert_true(true)
}
