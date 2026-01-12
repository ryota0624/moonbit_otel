// TracerOptions holds configuration for Tracer ID generation

///|
pub struct TracerOptions {
  trace_id_generator : () -> TraceID
  span_id_generator : () -> SpanID
  get_current_time_nanos : () -> Int64
}

// Create default TracerOptions using built-in generators

///|
pub fn TracerOptions::default(rand : @random.Rand) -> TracerOptions {
  {
    trace_id_generator: () => generate_trace_id(rand),
    span_id_generator: () => generate_span_id(rand),
    get_current_time_nanos: current_time_nanos,
  }
}

// Set custom trace ID generator

///|
pub fn TracerOptions::with_trace_id_generator(
  self : TracerOptions,
  generator : () -> TraceID,
) -> TracerOptions {
  { ..self, trace_id_generator: generator }
}

// Set custom span ID generator

///|
pub fn TracerOptions::with_span_id_generator(
  self : TracerOptions,
  generator : () -> SpanID,
) -> TracerOptions {
  { ..self, span_id_generator: generator }
}

// Tracer is responsible for creating Spans

///|
pub struct Tracer {
  identifier : TracerIdentifier // Identifier for this tracer
  resource : Resource // Resource associated with this tracer
  config : TracerOptions // Configuration for ID generation
}

///|
pub fn Tracer::name(self : Tracer) -> String {
  self.identifier.name
}

///|
pub fn Tracer::version(self : Tracer) -> String {
  self.identifier.version
}

///|
pub struct TracerIdentifier {
  name : String // Tracer name (usually the instrumentation library name)
  version : String // Tracer version
} derive(Hash, Eq)

///|
pub fn TracerIdentifier::new(
  name : String,
  version : String,
) -> TracerIdentifier {
  { name, version }
}

// Create a new Tracer with default configuration

///|
pub fn Tracer::new(
  name : String,
  version : String,
  resource : Resource,
  rand : @random.Rand,
) -> Tracer {
  let config = TracerOptions::default(rand)
  { identifier: { name, version }, resource, config }
}

// Create a new Tracer with custom configuration

///|
pub fn Tracer::with_config(
  name : String,
  version : String,
  resource : Resource,
  config : TracerOptions,
) -> Tracer {
  { identifier: { name, version }, resource, config }
}

// Tracer methods for creating spans

///|
pub fn Tracer::span_builder(self : Tracer, name : String) -> SpanBuilder {
  SpanBuilder::new(name, self.resource, self.identifier, self.config)
}

// Convenience method to start a span directly

///|
pub fn Tracer::start_span(
  self : Tracer,
  name : String,
  kind : SpanKind,
  parent : &SpanContextExtractable?,
) -> Span {
  let builder = SpanBuilder::new(
    name,
    self.resource,
    self.identifier,
    self.config,
  ).kind(kind)
  let builder_with_parent = match parent {
    Some(p) => builder.parent(p)
    None => builder
  }
  builder_with_parent.start()
}

///|
pub fn Tracer::span_event(
  self : Tracer,
  name : String,
  attributes? : Attributes = Default::default(),
  event_time? : Int64,
) -> SpanEvent {
  SpanEvent::new(
    name,
    event_time.unwrap_or_else(self.config.get_current_time_nanos),
    attributes,
  )
}
