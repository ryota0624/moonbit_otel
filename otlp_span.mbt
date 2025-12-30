/// TODO: 適切ファイルへ切り出し移動

// OTLP JSON serialization functions for converting MoonBit span structures
// to OpenTelemetry Protocol JSON format

// Helper structure for OTLP resourceSpans

///|
pub struct OtlpResourceSpans {
  resource_spans : Array[OtlpResourceSpan]
} derive(ToJson(rename_fields="camelCase"))

///|
fn OtlpResourceSpans::to_protobuf(
  self : OtlpResourceSpans,
) -> @trace.TracesData {
  let otlp_td = @trace.TracesData::default()
  otlp_td.resource_spans = []
  for rs in self.resource_spans {
    otlp_td.resource_spans.push(rs.to_protobuf())
  }
  otlp_td
}

///|
pub fn OtlpResourceSpans::from_spans(spans : Array[Span]) -> OtlpResourceSpans {
  if spans.length() == 0 {
    return { resource_spans: [] }
  }
  let spans_grouped_by_resource : Map[Resource, Array[Span]] = Map::new()
  for span in spans {
    let resource = span.resource
    if !spans_grouped_by_resource.contains(resource) {
      spans_grouped_by_resource[resource] = []
    }
    spans_grouped_by_resource[resource].push(span)
  }
  let spans_grouped_by_tracer_identifier : Map[
    Resource,
    Map[TracerIdentifier, Array[Span]],
  ] = Map::new()
  for rs in spans_grouped_by_resource {
    let (resource, spans) = rs
    let tracer_map : Map[TracerIdentifier, Array[Span]] = Map::new()
    for span in spans {
      let tracer_id = span.tracer_identifier
      if !tracer_map.contains(tracer_id) {
        tracer_map[tracer_id] = []
      }
      tracer_map[tracer_id].push(span)
    }
    spans_grouped_by_tracer_identifier[resource] = tracer_map
  }
  let scope_spans_from_map = OtlpResourceSpans::from_map(
    spans_grouped_by_tracer_identifier,
  )
  scope_spans_from_map
}

///|
pub struct OtlpResourceSpan {
  resource : Resource
  scope_spans : Array[OtlpScopeSpan]
  schemaUrl : String?
} derive(ToJson(rename_fields="camelCase"))

///|
pub fn OtlpResourceSpans::from_map(
  map : Map[Resource, Map[TracerIdentifier, Array[Span]]],
) -> OtlpResourceSpans {
  let resource_spans : Array[OtlpResourceSpan] = []
  for rm in map {
    let (resource, tracer_map) = rm
    let scope_spans = OtlpResourceSpan::from_map(tracer_map)
    let resource_span : OtlpResourceSpan = {
      resource,
      scope_spans,
      schemaUrl: None,
    }
    resource_spans.push(resource_span)
  }
  OtlpResourceSpans::{ resource_spans, }
}

///|
pub struct OtlpScopeSpan {
  scope : OtlpScope
  spans : Array[Span]
  schema_url : String?
} derive(ToJson(rename_fields="camelCase"))

///|
fn OtlpResourceSpan::from_map(
  map : Map[TracerIdentifier, Array[Span]],
) -> Array[OtlpScopeSpan] {
  let scope_spans : Array[OtlpScopeSpan] = []
  for ti in map {
    let (tracer_id, spans) = ti
    let scope : OtlpScope = { name: tracer_id.name, version: tracer_id.version }
    let scope_span : OtlpScopeSpan = { scope, spans, schema_url: None }
    scope_spans.push(scope_span)
  }
  scope_spans
}

///|
fn OtlpResourceSpan::to_protobuf(
  self : OtlpResourceSpan,
) -> @trace.ResourceSpans {
  let otlp_rs = @trace.ResourceSpans::default()
  otlp_rs.schema_url = self.schemaUrl.unwrap_or("")
  otlp_rs.resource = self.resource.to_protobuf()
  otlp_rs.scope_spans = []
  for ss in self.scope_spans {
    let otlp_ss = @trace.ScopeSpans::default()
    otlp_ss.schema_url = ss.schema_url.unwrap_or("")
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
pub struct OtlpScope {
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
  let otlp = OtlpResourceSpans::from_spans(spans)
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
  let otlp = OtlpResourceSpans::from_spans(spans)

  // Convert to protobuf TracesData
  let traces_data = otlp.to_protobuf()
  let buffer = @buffer.new()
  traces_data.write(buffer) catch {
    e => raise Failure("Protobuf serialization failed: " + e.to_string())
  }
  buffer.to_bytes()
}
