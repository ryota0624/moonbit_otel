// TracerConfig holds configuration for Tracer ID generation

///|
pub struct TracerConfig {
  trace_id_generator : () -> TraceID
  span_id_generator : () -> SpanID
}

// Create default TracerConfig using built-in generators

///|
pub fn TracerConfig::default(rand : @random.Rand) -> TracerConfig {
  {
    trace_id_generator: () => generate_trace_id(rand),
    span_id_generator: () => generate_span_id(rand),
  }
}

// Set custom trace ID generator

///|
pub fn TracerConfig::with_trace_id_generator(
  self : TracerConfig,
  generator : () -> TraceID,
) -> TracerConfig {
  { ..self, trace_id_generator: generator }
}

// Set custom span ID generator

///|
pub fn TracerConfig::with_span_id_generator(
  self : TracerConfig,
  generator : () -> SpanID,
) -> TracerConfig {
  { ..self, span_id_generator: generator }
}

// Tracer is responsible for creating Spans

///|
pub struct Tracer {
  name : String // Tracer name (usually the instrumentation library name)
  version : String // Tracer version
  resource : Resource // Resource associated with this tracer
  config : TracerConfig // Configuration for ID generation
}

// Create a new Tracer with default configuration

///|
pub fn Tracer::new(
  name : String,
  version : String,
  resource : Resource,
  rand : @random.Rand,
) -> Tracer {
  let config = TracerConfig::default(rand)
  { name, version, resource, config }
}

// Create a new Tracer with custom configuration

///|
pub fn Tracer::with_config(
  name : String,
  version : String,
  resource : Resource,
  config : TracerConfig,
) -> Tracer {
  { name, version, resource, config }
}

// SpanBuilder helps construct a Span with various options

///|
pub struct SpanBuilder {
  name : String
  kind : SpanKind
  parent_context : SpanContext?
  attributes : Map[String, AttributeValue]
  start_time : Int64?
}

// Create a new SpanBuilder

///|
pub fn SpanBuilder::new(name : String) -> SpanBuilder {
  {
    name,
    kind: SpanKind::Internal,
    parent_context: None,
    attributes: Map::new(),
    start_time: None,
  }
}

// Set the SpanKind

///|
pub fn SpanBuilder::with_kind(
  self : SpanBuilder,
  kind : SpanKind,
) -> SpanBuilder {
  { ..self, kind, }
}

// Set the parent SpanContext

///|
pub fn SpanBuilder::with_parent(
  self : SpanBuilder,
  parent : SpanContext,
) -> SpanBuilder {
  { ..self, parent_context: Some(parent) }
}

// Add an attribute

///|
pub fn SpanBuilder::with_attribute(
  self : SpanBuilder,
  key : String,
  value : AttributeValue,
) -> SpanBuilder {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, value)
  { ..self, attributes: new_attributes }
}

// Set the start time

///|
pub fn SpanBuilder::with_start_time(
  self : SpanBuilder,
  start_time : Int64,
) -> SpanBuilder {
  { ..self, start_time: Some(start_time) }
}

// Build the Span using the Tracer

///|
pub fn SpanBuilder::start(self : SpanBuilder, tracer : Tracer) -> Span {
  // Generate new trace and span IDs using tracer's config generators
  let trace_id = match self.parent_context {
    Some(parent) => parent.trace_id
    None => (tracer.config.trace_id_generator)()
  }
  let span_id = (tracer.config.span_id_generator)()
  let parent_span_id = match self.parent_context {
    Some(parent) => Some(parent.span_id)
    None => None
  }

  // Inherit trace flags from parent or default to sampled
  let trace_flags = match self.parent_context {
    Some(parent) => parent.trace_flags
    None => 0x01 // Sampled by default
  }
  let context = SpanContext::new(trace_id, span_id, trace_flags, false)

  // Use provided start time or default to 0 (in real implementation, use current time)
  let start_time = match self.start_time {
    Some(t) => t
    None => 0L // In production, this should be the current timestamp
  }
  let mut span = Span::new(
    context,
    self.name,
    self.kind,
    start_time,
    tracer.resource,
    parent_span_id,
  )

  // Add all attributes from the builder
  self.attributes.each(fn(key, value) {
    span = { ..span, attributes: span.attributes.set(key, value) }
  })
  span
}

// Tracer methods for creating spans

///|
pub fn Tracer::span_builder(_ : Tracer, name : String) -> SpanBuilder {
  SpanBuilder::new(name)
}

// Convenience method to start a span directly

///|
pub fn Tracer::start_span(
  self : Tracer,
  name : String,
  kind : SpanKind,
  parent : SpanContext?,
) -> Span {
  let builder = SpanBuilder::new(name).with_kind(kind)
  let builder_with_parent = match parent {
    Some(p) => builder.with_parent(p)
    None => builder
  }
  builder_with_parent.start(self)
}
