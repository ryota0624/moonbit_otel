// Tests for OTLP span serialization and conversion functions

// Helper functions for creating common test structures

///|
fn create_test_resource() -> Resource {
  Resource::empty()
  .with_string("service.name", "test-service")
  .with_string("service.version", "1.0.0")
}

///|
fn create_test_tracer_identifier() -> TracerIdentifier {
  TracerIdentifier::new("test-tracer", "0.1.0")
}

///|
fn create_test_span_context(
  trace_id_hex : String,
  span_id_hex : String,
) -> SpanContext {
  let trace_id = TraceID::new(trace_id_hex)
  let span_id = SpanID::new(span_id_hex)
  SpanContext::new(trace_id, span_id, TraceFlags::sampled(), false)
}

///|
fn create_basic_span(name : String) -> Span {
  let context = create_test_span_context(
    "0123456789abcdef0123456789abcdef", "0123456789abcdef",
  )
  let resource = create_test_resource()
  let tracer_id = create_test_tracer_identifier()
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

///|
fn create_span_with_parent(
  name : String,
  trace_id_hex : String,
  span_id_hex : String,
  parent_span_id_hex : String,
) -> Span {
  let context = create_test_span_context(trace_id_hex, span_id_hex)
  let resource = create_test_resource()
  let tracer_id = create_test_tracer_identifier()
  let parent_id = SpanID::new(parent_span_id_hex)
  Span::new(
    context,
    name,
    SpanKind::Server,
    1000000000L,
    resource,
    tracer_id,
    Some(parent_id),
  )
}

///|
fn create_span_with_attributes(name : String) -> Span {
  let span = create_basic_span(name)
  span
  .set_attribute("http.method", AttributeValue::String("GET"))
  .set_attribute("http.status_code", AttributeValue::Int(200))
  .set_attribute("http.url", AttributeValue::String("https://example.com"))
  .set_attribute("success", AttributeValue::Bool(true))
}

///|
fn create_span_with_events(name : String) -> Span {
  let span = create_basic_span(name)
  let event_attrs = Attributes::default()
    .set("event.type", AttributeValue::String("error"))
    .set("event.message", AttributeValue::String("Connection timeout"))
  let event = SpanEvent::new("error-occurred", timestamp=1000000L, event_attrs)
  span.add_event(event)
}

///|
fn create_span_with_different_resource() -> Span {
  let context = create_test_span_context(
    "0123456789abcdef0123456789abcdef", "1123456789abcdef",
  )
  let resource = Resource::empty().with_string("service.name", "other-service")
  let tracer_id = create_test_tracer_identifier()
  Span::new(
    context,
    "different-resource-span",
    SpanKind::Internal,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
}

///|
fn create_span_with_different_tracer() -> Span {
  let context = create_test_span_context(
    "0123456789abcdef0123456789abcdef", "2123456789abcdef",
  )
  let resource = create_test_resource()
  let tracer_id = TracerIdentifier::new("other-tracer", "2.0")
  Span::new(
    context,
    "different-tracer-span",
    SpanKind::Internal,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
}

// Tests for OtlpResourceSpans::from_spans

///|
test "OtlpResourceSpans::from_spans handles empty array" {
  let spans : Array[Span] = []
  let result = OtlpResourceSpans::from_spans(spans)
  assert_eq(result.resource_spans.length(), 0)
}

///|
test "OtlpResourceSpans::from_spans creates single resource span for same resource" {
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let spans = [span1, span2]
  let result = OtlpResourceSpans::from_spans(spans)

  // Both spans have the same resource, so should be grouped into one resource span
  assert_eq(result.resource_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans[0].spans.length(), 2)
}

///|
test "OtlpResourceSpans::from_spans groups spans by resource" {
  let span1 = create_basic_span("span1")
  let span2 = create_span_with_different_resource()
  let spans = [span1, span2]
  let result = OtlpResourceSpans::from_spans(spans)

  // Two different resources, so should create two resource spans
  assert_eq(result.resource_spans.length(), 2)
}

///|
test "OtlpResourceSpans::from_spans groups spans by tracer identifier" {
  let span1 = create_basic_span("span1")
  let span2 = create_span_with_different_tracer()
  let spans = [span1, span2]
  let result = OtlpResourceSpans::from_spans(spans)

  // Same resource but different tracers
  assert_eq(result.resource_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans.length(), 2)
}

///|
test "OtlpResourceSpans::from_spans handles complex grouping" {
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let span3 = create_span_with_different_resource()
  let span4 = create_span_with_different_tracer()
  let spans = [span1, span2, span3, span4]
  let result = OtlpResourceSpans::from_spans(spans)

  // Should have 2 resource spans (2 different resources)
  assert_eq(result.resource_spans.length(), 2)
}

// Tests for OtlpResourceSpans::from_map

///|
test "OtlpResourceSpans::from_map handles empty map" {
  let map : Map[Resource, Map[TracerIdentifier, Array[Span]]] = Map::new()
  let result = OtlpResourceSpans::from_map(map)
  assert_eq(result.resource_spans.length(), 0)
}

///|
test "OtlpResourceSpans::from_map creates resource spans from map" {
  let resource1 = create_test_resource()
  let resource2 = Resource::empty().with_string("service.name", "other-service")
  let tracer1 = create_test_tracer_identifier()
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let map : Map[Resource, Map[TracerIdentifier, Array[Span]]] = Map::new()
  let tracer_map1 : Map[TracerIdentifier, Array[Span]] = Map::new()
  tracer_map1[tracer1] = [span1]
  map[resource1] = tracer_map1
  let tracer_map2 : Map[TracerIdentifier, Array[Span]] = Map::new()
  tracer_map2[tracer1] = [span2]
  map[resource2] = tracer_map2
  let result = OtlpResourceSpans::from_map(map)
  assert_eq(result.resource_spans.length(), 2)
}

///|
test "OtlpResourceSpans::from_map handles multiple tracers per resource" {
  let resource = create_test_resource()
  let tracer1 = TracerIdentifier::new("tracer1", "1.0")
  let tracer2 = TracerIdentifier::new("tracer2", "2.0")
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let map : Map[Resource, Map[TracerIdentifier, Array[Span]]] = Map::new()
  let tracer_map : Map[TracerIdentifier, Array[Span]] = Map::new()
  tracer_map[tracer1] = [span1]
  tracer_map[tracer2] = [span2]
  map[resource] = tracer_map
  let result = OtlpResourceSpans::from_map(map)
  assert_eq(result.resource_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans.length(), 2)
}

///|
test "OtlpResourceSpans::from_map preserves span data" {
  let resource = create_test_resource()
  let tracer = create_test_tracer_identifier()
  let span = create_basic_span("test-span-name")
  let map : Map[Resource, Map[TracerIdentifier, Array[Span]]] = Map::new()
  let tracer_map : Map[TracerIdentifier, Array[Span]] = Map::new()
  tracer_map[tracer] = [span]
  map[resource] = tracer_map
  let result = OtlpResourceSpans::from_map(map)
  assert_eq(result.resource_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans.length(), 1)
  assert_eq(result.resource_spans[0].scope_spans[0].spans.length(), 1)
  assert_eq(
    result.resource_spans[0].scope_spans[0].spans[0].name,
    "test-span-name",
  )
}

// Tests for spans_to_resource_spans_json

///|
test "spans_to_resource_spans_json handles empty array" {
  let spans : Array[Span] = []
  let json = spans_to_resource_spans_json(spans)
  assert_eq(json, "{\"resourceSpans\":[]}")
}

///|
test "spans_to_resource_spans_json produces valid JSON structure" {
  let span = create_basic_span("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("resourceSpans"))
  assert_true(json.contains("scopeSpans"))
  assert_true(json.contains("spans"))
  assert_true(json.contains("resource"))
  assert_true(json.contains("scope"))
}

///|
test "spans_to_resource_spans_json includes span name" {
  let span = create_basic_span("my-test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("my-test-span"))
}

///|
test "spans_to_resource_spans_json includes trace and span IDs" {
  let trace_id = "aabbccdd00112233aabbccdd00112233"
  let span_id = "aabbccdd00112233"
  let context = create_test_span_context(trace_id, span_id)
  let resource = create_test_resource()
  let tracer_id = create_test_tracer_identifier()
  let span = Span::new(
    context,
    "test-span",
    SpanKind::Internal,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains(trace_id))
  assert_true(json.contains(span_id))
}

///|
test "spans_to_resource_spans_json serializes span with attributes" {
  let span = create_span_with_attributes("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  // Verify the span is present in the JSON
  assert_true(json.contains("test-span"))
  assert_true(json.contains("resourceSpans"))
}

///|
test "spans_to_resource_spans_json serializes span with events" {
  let span = create_span_with_events("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  // Verify the span is present in the JSON
  assert_true(json.contains("test-span"))
  assert_true(json.contains("resourceSpans"))
}

///|
test "spans_to_resource_spans_json includes resource attributes" {
  let span = create_basic_span("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("service.name"))
  assert_true(json.contains("test-service"))
  assert_true(json.contains("service.version"))
  assert_true(json.contains("1.0.0"))
}

///|
test "spans_to_resource_spans_json includes tracer information" {
  let span = create_basic_span("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("test-tracer"))
  assert_true(json.contains("0.1.0"))
}

///|
test "spans_to_resource_spans_json handles multiple spans" {
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let span3 = create_basic_span("span3")
  let spans = [span1, span2, span3]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("span1"))
  assert_true(json.contains("span2"))
  assert_true(json.contains("span3"))
}

///|
test "spans_to_resource_spans_json handles parent-child span relationship" {
  let trace_id = "aabbccdd00112233aabbccdd00112233"
  let parent_span_id = "1111111111111111"
  let child_span_id = "2222222222222222"
  let parent_context = create_test_span_context(trace_id, parent_span_id)
  let resource = create_test_resource()
  let tracer_id = create_test_tracer_identifier()
  let parent_span = Span::new(
    parent_context,
    "parent-span",
    SpanKind::Server,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
  let child_span = create_span_with_parent(
    "child-span", trace_id, child_span_id, parent_span_id,
  )
  let spans = [parent_span, child_span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("parent-span"))
  assert_true(json.contains("child-span"))
  assert_true(json.contains(parent_span_id))
  assert_true(json.contains(child_span_id))
}

// Tests for spans_to_resource_spans_protobuf_bytes

///|
test "spans_to_resource_spans_protobuf_bytes handles empty array" {
  let spans : Array[Span] = []
  let bytes = spans_to_resource_spans_protobuf_bytes(spans) catch {
    _ => panic()
  }
  assert_eq(bytes.length(), 0)
}

///|
test "spans_to_resource_spans_protobuf_bytes produces non-empty output" {
  let span = create_basic_span("test-span")
  let spans = [span]
  let bytes = spans_to_resource_spans_protobuf_bytes(spans) catch {
    _ => {
      assert_true(false)
      Bytes::new(0)
    }
  }
  assert_true(bytes.length() > 0)
}

///|
test "spans_to_resource_spans_protobuf_bytes produces different output for different spans" {
  let span1 = create_basic_span("span1")
  let span2 = create_basic_span("span2")
  let bytes1 = spans_to_resource_spans_protobuf_bytes([span1]) catch {
    _ => panic()
  }
  let bytes2 = spans_to_resource_spans_protobuf_bytes([span2]) catch {
    _ => panic()
  }

  // The protobuf output should be different for different span names
  assert_true(bytes1.length() != bytes2.length() || bytes1 != bytes2)
}

///|
test "spans_to_resource_spans_protobuf_bytes handles complex spans" {
  let span_with_attrs = create_span_with_attributes("span-attrs")
  let span_with_events = create_span_with_events("span-events")
  let basic_span = create_basic_span("basic-span")
  let spans = [span_with_attrs, span_with_events, basic_span]
  let bytes = spans_to_resource_spans_protobuf_bytes(spans) catch {
    _ => {
      assert_true(false)
      Bytes::new(0)
    }
  }
  // Should produce output with attributes and events
  assert_true(bytes.length() > 100)
}

// Tests for span with various status codes

///|
test "spans_to_resource_spans_json handles span with OK status" {
  let span = create_basic_span("test-span").set_status(SpanStatus::Ok)
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("STATUS_CODE_OK"))
}

///|
test "spans_to_resource_spans_json handles span with Error status" {
  let span = create_basic_span("test-span").set_status(SpanStatus::Error)
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("STATUS_CODE_ERROR"))
}

///|
test "spans_to_resource_spans_json handles span with Unset status" {
  let span = create_basic_span("test-span")
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("STATUS_CODE_UNSET"))
}

// Tests for different span kinds

///|
test "spans_to_resource_spans_json handles different span kinds" {
  let context = create_test_span_context(
    "0123456789abcdef0123456789abcdef", "0123456789abcdef",
  )
  let resource = create_test_resource()
  let tracer_id = create_test_tracer_identifier()
  let client_span = Span::new(
    context,
    "client-span",
    SpanKind::Client,
    1000000000L,
    resource,
    tracer_id,
    None,
  )
  let json = spans_to_resource_spans_json([client_span])
  assert_true(json.contains("client-span"))
  assert_true(json.contains("SPAN_KIND_CLIENT"))
}

// Tests for timestamp handling

///|
test "spans_to_resource_spans_json includes timestamps" {
  let span = create_basic_span("test-span").end(end_time_ns=2000000000L)
  let spans = [span]
  let json = spans_to_resource_spans_json(spans)
  assert_true(json.contains("startTimeUnixNano"))
  assert_true(json.contains("endTimeUnixNano"))
  assert_true(json.contains("1000000000"))
  assert_true(json.contains("2000000000"))
}
