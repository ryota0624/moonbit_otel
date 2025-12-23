// OTLP JSON serialization functions for converting MoonBit span structures
// to OpenTelemetry Protocol JSON format

// Helper structure for OTLP resourceSpans
struct OtlpResourceSpans {
  resourceSpans : Array[OtlpResourceSpan]
} derive(ToJson)

struct OtlpResourceSpan {
  resource : Resource
  scopeSpans : Array[OtlpScopeSpan]
} derive(ToJson)

struct OtlpScopeSpan {
  scope : OtlpScope
  spans : Array[Span]
} derive(ToJson)

struct OtlpScope {
  name : String
  version : String
} derive(ToJson)

// Serialize a single Span to OTLP JSON format using ToJson
pub fn span_to_json(span : Span) -> String {
  span.to_json().stringify()
}

// Serialize an array of Spans to OTLP resourceSpans JSON format
pub fn spans_to_resource_spans_json(spans : Array[Span]) -> String {
  if spans.length() == 0 {
    return "{\"resourceSpans\":[]}"
  }

  // Use first span's resource
  let resource = spans[0].resource

  // Build OTLP structure
  let scope : OtlpScope = { name: "otel-tracer", version: "1.0.0" }
  let scope_span : OtlpScopeSpan = { scope, spans }
  let resource_span : OtlpResourceSpan = { resource, scopeSpans: [scope_span] }
  let otlp : OtlpResourceSpans = { resourceSpans: [resource_span] }

  otlp.to_json().stringify()
}
