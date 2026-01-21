// Tests for Context

///|
test "Context::empty creates an empty context" {
  let ctx = Context::empty()
  assert_eq(ctx.size(), 0)
}

///|
test "Context::with_string adds a string value" {
  let ctx = Context::empty().with_string("key1", "value1")
  assert_eq(ctx.get_string("key1"), Some("value1"))
  assert_eq(ctx.size(), 1)
}

///|
test "Context::with_int adds an int value" {
  let ctx = Context::empty().with_int("count", 42)
  assert_eq(ctx.get_int("count"), Some(42))
}

///|
test "Context::with_bool adds a bool value" {
  let ctx = Context::empty().with_bool("flag", true)
  assert_eq(ctx.get_bool("flag"), Some(true))
}

///|
test "Context::with_double adds a double value" {
  let ctx = Context::empty().with_double("pi", 3.14)
  assert_eq(ctx.get_double("pi"), Some(3.14))
}

///|
test "Context::get returns None for non-existent key" {
  let ctx = Context::empty()
  assert_eq(ctx.get_string("missing"), None)
}

///|
test "Context is immutable - original unchanged after with_string" {
  let ctx1 = Context::empty()
  let ctx2 = ctx1.with_string("key", "value")
  assert_eq(ctx1.size(), 0)
  assert_eq(ctx2.size(), 1)
}

///|
test "Context::contains checks key existence" {
  let ctx = Context::empty().with_string("key", "value")
  assert_true(ctx.contains("key"))
  assert_false(ctx.contains("missing"))
}

///|
test "Context can store multiple values" {
  let ctx = Context::empty()
    .with_string("name", "test")
    .with_int("count", 10)
    .with_bool("enabled", true)
  assert_eq(ctx.size(), 3)
  assert_eq(ctx.get_string("name"), Some("test"))
  assert_eq(ctx.get_int("count"), Some(10))
  assert_eq(ctx.get_bool("enabled"), Some(true))
}

// Tests for Resource

///|
test "Resource::empty creates an empty resource" {
  let res = Resource::empty()
  assert_eq(res.size(), 0)
}

///|
test "Resource::with_string adds a string attribute" {
  let res = Resource::empty().with_string(service_name, "my-service")
  assert_eq(res.get_string(service_name), Some("my-service"))
  assert_eq(res.size(), 1)
}

///|
test "Resource::with_int adds an int attribute" {
  let res = Resource::empty().with_int("port", 8080)
  assert_eq(res.get_int("port"), Some(8080))
}

///|
test "Resource::with_bool adds a bool attribute" {
  let res = Resource::empty().with_bool("debug", false)
  assert_eq(res.get_bool("debug"), Some(false))
}

///|
test "Resource::with_double adds a double attribute" {
  let res = Resource::empty().with_double("version", 1.5)
  assert_eq(res.get_double("version"), Some(1.5))
}

// Note: StringArray attribute type is not currently implemented
// ///|
// test "Resource::with_string_array adds a string array attribute" {
//   let res = Resource::empty().with_string_array("tags", ["prod", "web"])
//   match res.get("tags") {
//     Some(AttributeValue::StringArray(arr)) => assert_eq(arr, ["prod", "web"])
//     _ => fail("Expected StringArray")
//   }
// }

///|
test "Resource is immutable - original unchanged after with_string" {
  let res1 = Resource::empty()
  let res2 = res1.with_string(service_name, "service1")
  assert_eq(res1.size(), 0)
  assert_eq(res2.size(), 1)
}

///|
test "Resource::contains checks attribute existence" {
  let res = Resource::empty().with_string(service_name, "my-service")
  assert_true(res.contains(service_name))
  assert_false(res.contains("missing"))
}

///|
test "Resource::merge combines two resources" {
  let res1 = Resource::empty()
    .with_string(service_name, "service1")
    .with_string(service_version, "1.0.0")
  let res2 = Resource::empty()
    .with_string(service_namespace, "production")
    .with_string(service_version, "2.0.0") // This should override
  let merged = res1.merge(res2)
  assert_eq(merged.size(), 3)
  assert_eq(merged.get_string(service_name), Some("service1"))
  assert_eq(merged.get_string(service_namespace), Some("production"))
  assert_eq(merged.get_string(service_version), Some("2.0.0")) // res2 takes precedence
}

///|
test "Resource can store multiple attribute types" {
  let res = Resource::empty()
    .with_string(service_name, "my-service")
    .with_int("port", 8080)
    .with_bool("debug", true)
    .with_double("cpu_limit", 2.5)
  assert_eq(res.size(), 4)
  assert_eq(res.get_string(service_name), Some("my-service"))
  assert_eq(res.get_int("port"), Some(8080))
  assert_eq(res.get_bool("debug"), Some(true))
  assert_eq(res.get_double("cpu_limit"), Some(2.5))
}

// Tests for Span and Tracer

///|
test "SpanContext::new creates a valid span context" {
  let trace_id = TraceID::new("12345678901234567890123456789012")
  let span_id = SpanID::new("1234567890123456")
  let ctx = SpanContext::new(trace_id, span_id, TraceFlags::sampled(), false)
  assert_true(ctx.is_valid())
  assert_true(ctx.is_sampled())
  assert_eq(ctx.trace_id.to_string(), "12345678901234567890123456789012")
  assert_eq(ctx.span_id.to_string(), "1234567890123456")
}

///|
test "SpanContext::is_valid returns false for zero IDs" {
  let trace_id = TraceID::new("00000000000000000000000000000000")
  let span_id = SpanID::new("0000000000000000")
  let ctx = SpanContext::new(trace_id, span_id, TraceFlags::sampled(), false)
  assert_false(ctx.is_valid())
}

///|
test "generate_trace_id creates 32-character hex string" {
  let rand = rand_by_current_time()
  let trace_id = generate_trace_id(rand)
  assert_eq(trace_id.to_string().length(), 32)
}

///|
test "generate_span_id creates 16-character hex string" {
  let rand = rand_by_current_time()
  let span_id = generate_span_id(rand)
  assert_eq(span_id.to_string().length(), 16)
}

///|
test "Span::new creates a new span" {
  let rand = rand_by_current_time()
  let ctx = SpanContext::new(
    generate_trace_id(rand),
    generate_span_id(rand),
    TraceFlags::sampled(),
    false,
  )
  let resource = Resource::empty().with_string(service_name, "test-service")
  let span = Span::new(
    ctx,
    "test-span",
    SpanKind::Internal,
    1000L,
    resource,
    TracerIdentifier::new("test-tracer", "1.0.0"),
    None,
  )
  assert_eq(span.name, "test-span")
  assert_eq(span.kind, SpanKind::Internal)
  assert_eq(span.start_time_unix_nano, 1000L)
  assert_false(span.is_ended())
}

///|
test "Span::set_attribute adds an attribute" {
  let span = create_test_span().set_attribute(
    "http.method",
    AttributeValue::String("GET"),
  )
  assert_eq(
    span.attributes.get("http.method"),
    Some(AttributeValue::String("GET")),
  )
}

///|
test "Span::add_event adds an event to the span" {
  let span = create_test_span()
  let event = SpanEvent::new("error", timestamp=2000L, Attributes::empty())
  let span_with_event = span.add_event(event)
  assert_eq(span_with_event.events.length(), 1)
  assert_eq(span_with_event.events[0].name, "error")
}

///|
test "Span::end marks the span as ended" {
  let trace_id = TraceID::new("5b8efff798038103d269b633813fc60c")
  let span_id = SpanID::new("eee19b7ec3c1b174")
  let context = SpanContext::new(
    trace_id,
    span_id,
    TraceFlags::sampled(),
    false,
  )
  let tracer_identifier = TracerIdentifier::new("test-tracer", "1.0.0")
  let resource = Resource::empty()
  let span = Span::new(
    context,
    "test-span",
    SpanKind::Internal,
    1000L,
    resource,
    tracer_identifier,
    None,
  ).end(end_time_ns=3000L)
  assert_true(span.is_ended())
  assert_eq(span.duration(), Some(2000L))
}

///|
test "Span::set_status sets the span status" {
  let span = create_test_span().set_status(SpanStatus::Ok)
  assert_eq(span.status, SpanStatus::Ok)
}

///|
test "Tracer::new creates a tracer" {
  let resource = Resource::empty().with_string(service_name, "my-service")
  let tracer = Tracer::new("my-library", "1.0.0", resource)
  assert_eq(tracer.name(), "my-library")
  assert_eq(tracer.version(), "1.0.0")
}

///|
test "Tracer::start_span creates a span" {
  let resource = Resource::empty().with_string(service_name, "my-service")
  let tracer = Tracer::new("my-library", "1.0.0", resource)
  let span = tracer.start_span("operation", kind=SpanKind::Server)
  assert_eq(span.name, "operation")
  assert_eq(span.kind, SpanKind::Server)
  assert_true(span.traceId.is_valid() && span.spanId.is_valid())
}

///|
test "Tracer creates child span with parent context" {
  let resource = Resource::empty().with_string(service_name, "my-service")
  let tracer = Tracer::new("my-library", "1.0.0", resource)
  let parent_span = tracer.start_span("parent", kind=SpanKind::Server)
  let parent_context = SpanContext::new(
    parent_span.traceId,
    parent_span.spanId,
    parent_span.trace_flags,
    false,
  )
  let child_span = tracer.start_span(
    "child",
    kind=SpanKind::Internal,
    parent=parent_context,
  )
  assert_eq(child_span.traceId, parent_span.traceId)
  assert_eq(child_span.parent_span_id, Some(parent_span.spanId))
}
