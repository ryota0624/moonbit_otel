/// TODO: 適切ファイルへ切り出し移動

// OTLP JSON serialization functions for converting MoonBit span structures
// to OpenTelemetry Protocol JSON format

// Helper structure for OTLP resourceSpans

///|
struct OtlpResourceSpans {
  resourceSpans : Array[OtlpResourceSpan]
} derive(ToJson)

///|
fn OtlpResourceSpans::to_protobuf(
  self : OtlpResourceSpans,
) -> @trace.TracesData {
  let otlp_td = @trace.TracesData::default()
  otlp_td.resource_spans = []
  for rs in self.resourceSpans {
    otlp_td.resource_spans.push(rs.to_protobuf())
  }
  otlp_td
}

///|
struct OtlpResourceSpan {
  resource : Resource
  scopeSpans : Array[OtlpScopeSpan]
  schemaUrl : String?
} derive(ToJson)

///|
struct OtlpScopeSpan {
  scope : OtlpScope
  spans : Array[Span]
  schemaUrl : String?
} derive(ToJson)

///|
fn OtlpResourceSpan::to_protobuf(
  self : OtlpResourceSpan,
) -> @trace.ResourceSpans {
  let otlp_rs = @trace.ResourceSpans::default()
  otlp_rs.schema_url = self.schemaUrl.unwrap_or("")
  otlp_rs.resource = self.resource.to_protobuf()
  otlp_rs.scope_spans = []
  for ss in self.scopeSpans {
    let otlp_ss = @trace.ScopeSpans::default()
    otlp_ss.schema_url = ss.schemaUrl.unwrap_or("")
    otlp_ss.scope = @otel_common.InstrumentationScope::default()
    otlp_ss.scope.name = ss.scope.name
    otlp_ss.scope.version = ss.scope.version
    otlp_ss.spans = []
    for span in ss.spans {
      otlp_ss.spans.push(span.to_protobuf())
    }
    otlp_rs.scope_spans.push(otlp_ss)
  }
  otlp_rs
}

///|
struct OtlpScope {
  name : String
  version : String
} derive(ToJson)

// Serialize a single Span to OTLP JSON format using ToJson
// Serialize an array of Spans to OTLP resourceSpans JSON format

///|
pub fn spans_to_resource_spans_json(spans : Array[Span]) -> String {
  if spans.length() == 0 {
    return "{\"resourceSpans\":[]}"
  }

  // Use first span's resource
  let resource = spans[0].resource

  // Build OTLP structure
  let scope : OtlpScope = { name: "otel-tracer", version: "1.0.0" }
  let scope_span : OtlpScopeSpan = { scope, spans, schemaUrl: None }
  let resource_span : OtlpResourceSpan = {
    resource,
    scopeSpans: [scope_span],
    schemaUrl: None,
  }
  let otlp : OtlpResourceSpans = { resourceSpans: [resource_span] }
  otlp.to_json().stringify()
}

// Serialize an array of Spans to OTLP resourceSpans JSON format

///|
pub fn spans_to_resource_spans_protobuf_bytes(
  spans : Array[Span],
) -> Bytes raise {
  if spans.length() == 0 {
    return Bytes::new(0)
  }
  // Use first span's resource
  let resource = spans[0].resource

  // Build OTLP structure
  let scope : OtlpScope = { name: "otel-tracer", version: "1.0.0" }
  let scope_span : OtlpScopeSpan = { scope, spans, schemaUrl: None }
  let resource_span : OtlpResourceSpan = {
    resource,
    scopeSpans: [scope_span],
    schemaUrl: None,
  }
  let otlp : OtlpResourceSpans = { resourceSpans: [resource_span] }

  // Convert to protobuf TracesData
  let traces_data = otlp.to_protobuf()
  let buffer = @buffer.new()
  traces_data.write(buffer) catch {
    e => raise Failure("Protobuf serialization failed: " + e.to_string())
  }
  buffer.to_bytes()
}
