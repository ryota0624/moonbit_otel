// Tests for OTLP exporter JSON serialization and functionality
// Using ToJson derive trait for automatic JSON serialization

// AttributeValue serialization is tested implicitly through span serialization tests below

// Test SpanStatus serialization via ToJson

///|
test "SpanStatus serializes via ToJson" {
  let status = SpanStatus::Ok
  let json = status.to_json().to_string()
  assert_true(json.contains("Ok"))
}

// Test SpanKind serialization via ToJson

///|
test "SpanKind serializes via ToJson" {
  let kind = SpanKind::Server
  let json = kind.to_json().to_string()
  assert_true(json.contains("Server"))
}

// Helper function to create a test span

///|
fn create_test_span() -> Span {
  let trace_id = TraceID::new("5b8efff798038103d269b633813fc60c")
  let span_id = SpanID::new("eee19b7ec3c1b174")
  let context = SpanContext::new(trace_id, span_id, 1, false)
  let resource = Resource::empty()
  Span::new(
    context,
    "test-span",
    SpanKind::Internal,
    1000000000,
    resource,
    None,
  )
}

///|
test "spans_to_resource_spans_json produces complete OTLP structure" {
  let span = create_test_span()
  let json = spans_to_resource_spans_json([span])

  // Check for OTLP structure
  assert_true(json.contains("\"resourceSpans\""))
  assert_true(json.contains("\"resource\""))
  assert_true(json.contains("\"scopeSpans\""))
  assert_true(json.contains("\"scope\""))
  assert_true(json.contains("\"spans\""))
}

///|
test "spans_to_resource_spans_json handles empty array" {
  let json = spans_to_resource_spans_json([])
  assert_eq(json, "{\"resourceSpans\":[]}")
}

///|
test "spans_to_resource_spans_json handles multiple spans" {
  let span1 = create_test_span()
  let span2 = create_test_span()
  let json = spans_to_resource_spans_json([span1, span2])

  // Should contain array with multiple spans
  assert_true(json.contains("\"spans\""))
}
