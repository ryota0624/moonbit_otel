// OTLP JSON serialization functions for converting MoonBit span structures
// to OpenTelemetry Protocol JSON format

// Escape special characters in JSON strings
pub fn escape_json_string(s : String) -> String {
  let mut result = ""
  let mut i = 0
  let len = s.length()

  while i < len {
    let code = s.code_unit_at(i)
    match code {
      34 => result = result + "\\\""   // "
      92 => result = result + "\\\\"   // \
      10 => result = result + "\\n"    // \n
      13 => result = result + "\\r"    // \r
      9 => result = result + "\\t"     // \t
      _ => {
        // For other characters, use substring to extract single char
        let char_str = s.substring(start=i, end=i + 1)
        result = result + char_str
      }
    }
    i = i + 1
  }
  result
}

// Convert AttributeValue to OTLP JSON representation
pub fn attribute_value_to_json(value : AttributeValue) -> String {
  match value {
    AttributeValue::String(s) =>
      "{\"stringValue\":\"" + escape_json_string(s) + "\"}"
    AttributeValue::Int(i) => "{\"intValue\":\"" + i.to_string() + "\"}"
    AttributeValue::Bool(b) => "{\"boolValue\":" + b.to_string() + "}"
    AttributeValue::Double(d) => "{\"doubleValue\":" + d.to_string() + "}"
    AttributeValue::StringArray(arr) => {
      let mut result = "{\"arrayValue\":{\"values\":["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ","
        }
        result = result + "{\"stringValue\":\"" + escape_json_string(arr[i]) + "\"}"
      }
      result + "]}}"
    }
    AttributeValue::IntArray(arr) => {
      let mut result = "{\"arrayValue\":{\"values\":["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ","
        }
        result = result + "{\"intValue\":\"" + arr[i].to_string() + "\"}"
      }
      result + "]}}"
    }
    AttributeValue::BoolArray(arr) => {
      let mut result = "{\"arrayValue\":{\"values\":["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ","
        }
        result = result + "{\"boolValue\":" + arr[i].to_string() + "}"
      }
      result + "]}}"
    }
    AttributeValue::DoubleArray(arr) => {
      let mut result = "{\"arrayValue\":{\"values\":["
      for i = 0; i < arr.length(); i = i + 1 {
        if i > 0 {
          result = result + ","
        }
        result = result + "{\"doubleValue\":" + arr[i].to_string() + "}"
      }
      result + "]}}"
    }
  }
}

// Convert SpanKind to OTLP integer representation
pub fn span_kind_to_int(kind : SpanKind) -> Int {
  match kind {
    SpanKind::Internal => 1
    SpanKind::Server => 2
    SpanKind::Client => 3
    SpanKind::Producer => 4
    SpanKind::Consumer => 5
  }
}

// Convert SpanStatus to OTLP JSON representation
pub fn span_status_to_json(status : SpanStatus) -> String {
  match status {
    SpanStatus::Unset => "{\"code\":0}"
    SpanStatus::Ok => "{\"code\":1}"
    SpanStatus::Error => "{\"code\":2}"
  }
}

// Serialize attributes map to OTLP JSON array format
fn attributes_to_json_array(attributes : Map[String, AttributeValue]) -> String {
  let mut result = "["
  let mut first = true
  attributes.each(fn(key, value) {
    if not(first) {
      result = result + ","
    }
    result = result +
      "{\"key\":\"" +
      escape_json_string(key) +
      "\",\"value\":" +
      attribute_value_to_json(value) +
      "}"
    first = false
  })
  result + "]"
}

// Serialize span events to OTLP JSON array format
fn events_to_json_array(events : Array[SpanEvent]) -> String {
  let mut result = "["
  for i = 0; i < events.length(); i = i + 1 {
    if i > 0 {
      result = result + ","
    }
    let event = events[i]
    result = result +
      "{\"timeUnixNano\":\"" +
      event.timestamp.to_string() +
      "\",\"name\":\"" +
      escape_json_string(event.name) +
      "\",\"attributes\":" +
      attributes_to_json_array(event.attributes) +
      "}"
  }
  result + "]"
}

// Serialize Resource attributes to OTLP JSON array format
fn resource_to_json(resource : Resource) -> String {
  let mut attributes_list = "["
  let mut first = true
  resource.attributes.each(fn(key, value) {
    if not(first) {
      attributes_list = attributes_list + ","
    }
    attributes_list = attributes_list +
      "{\"key\":\"" +
      escape_json_string(key) +
      "\",\"value\":" +
      attribute_value_to_json(value) +
      "}"
    first = false
  })
  attributes_list = attributes_list + "]"
  "{\"attributes\":" + attributes_list + "}"
}

// Serialize a single Span to OTLP JSON format
pub fn span_to_json(span : Span) -> String {
  let mut json = "{"
  json = json + "\"traceId\":\"" + span.context.trace_id.to_string() + "\""
  json = json + ",\"spanId\":\"" + span.context.span_id.to_string() + "\""

  // Add parent span ID if present
  match span.parent_span_id {
    Some(parent_id) =>
      json = json + ",\"parentSpanId\":\"" + parent_id.to_string() + "\""
    None => ()
  }

  json = json + ",\"name\":\"" + escape_json_string(span.name) + "\""
  json = json + ",\"kind\":" + span_kind_to_int(span.kind).to_string()
  json = json + ",\"startTimeUnixNano\":\"" + span.start_time.to_string() + "\""

  // Add end time if present
  match span.end_time {
    Some(end) =>
      json = json + ",\"endTimeUnixNano\":\"" + end.to_string() + "\""
    None => ()
  }

  // Add attributes
  json = json + ",\"attributes\":" + attributes_to_json_array(span.attributes)

  // Add events
  json = json + ",\"events\":" + events_to_json_array(span.events)

  // Add status
  json = json + ",\"status\":" + span_status_to_json(span.status)

  json + "}"
}

// Serialize an array of Spans to OTLP resourceSpans JSON format
pub fn spans_to_resource_spans_json(spans : Array[Span]) -> String {
  if spans.length() == 0 {
    return "{\"resourceSpans\":[]}"
  }

  // Group spans by resource (all spans should have same resource in current impl)
  // For now, use first span's resource
  let resource = spans[0].resource
  let tracer_name = "otel-tracer"
  let tracer_version = "1.0.0"

  // Build spans array
  let mut spans_json = "["
  for i = 0; i < spans.length(); i = i + 1 {
    if i > 0 {
      spans_json = spans_json + ","
    }
    spans_json = spans_json + span_to_json(spans[i])
  }
  spans_json = spans_json + "]"

  // Build complete OTLP structure
  let json = "{\"resourceSpans\":[{\"resource\":" +
    resource_to_json(resource) +
    ",\"scopeSpans\":[{\"scope\":{\"name\":\"" +
    escape_json_string(tracer_name) +
    "\",\"version\":\"" +
    escape_json_string(tracer_version) +
    "\"},\"spans\":" +
    spans_json +
    "}]}]}"

  json
}
