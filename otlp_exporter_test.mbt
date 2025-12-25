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
test "span_to_json produces valid JSON structure" {
  let span = create_test_span()
  let json = span_to_json(span)

  // Check for required fields
  assert_true(json.contains("\"traceId\""))
  assert_true(json.contains("\"spanId\""))
  assert_true(json.contains("\"name\""))
  assert_true(json.contains("\"kind\""))
  assert_true(json.contains("\"startTimeUnixNano\""))
  assert_true(json.contains("\"attributes\""))
  assert_true(json.contains("\"events\""))
  assert_true(json.contains("\"status\""))
}

///|
test "span_to_json includes trace ID" {
  let span = create_test_span()
  let json = span_to_json(span)
  assert_true(json.contains("\"traceId\":\"5b8efff798038103d269b633813fc60c\""))
}

///|
test "span_to_json includes span ID" {
  let span = create_test_span()
  let json = span_to_json(span)
  assert_true(json.contains("\"spanId\":\"eee19b7ec3c1b174\""))
}

///|
test "span_to_json includes span name" {
  let span = create_test_span()
  let json = span_to_json(span)
  assert_true(json.contains("\"name\":\"test-span\""))
}

///|
test "span_to_json includes span kind code" {
  let span = create_test_span()
  let json = span_to_json(span)
  // Internal kind = 1
  assert_true(json.contains("\"kind\":1"))
}

///|
test "span_to_json includes span with parent span ID" {
  let trace_id = TraceID::new("5b8efff798038103d269b633813fc60c")
  let span_id = SpanID::new("eee19b7ec3c1b174")
  let parent_id = SpanID::new("eee19b7ec3c1b173")
  let context = SpanContext::new(trace_id, span_id, 1, false)
  let resource = Resource::empty()
  let span = Span::new(
    context,
    "test-span",
    SpanKind::Server,
    1000000000,
    resource,
    Some(parent_id),
  )
  let json = span_to_json(span)
  assert_true(json.contains("\"parentSpanId\":\"eee19b7ec3c1b173\""))
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
