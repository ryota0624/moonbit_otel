// SpanBuilder helps construct a Span with various options

///|
pub struct SpanBuilder {
  priv name : String
  priv kind : SpanKind
  priv parent_context : SpanContext?
  priv attributes : Map[String, AttributeValue]
  priv start_time : Int64?
  priv resource : Resource
  priv tracer_identifier : TracerIdentifier
  priv tracer_config : TracerOptions
}

// Create a new SpanBuilder

///|
pub fn SpanBuilder::new(
  name : String,
  resource : Resource,
  tracer_identifier : TracerIdentifier,
  tracer_config : TracerOptions,
) -> SpanBuilder {
  {
    name,
    kind: SpanKind::Internal,
    parent_context: None,
    attributes: Map::new(),
    start_time: None,
    resource,
    tracer_identifier,
    tracer_config,
  }
}

// Set the SpanKind

///|
pub fn SpanBuilder::kind(self : SpanBuilder, kind : SpanKind) -> SpanBuilder {
  { ..self, kind, }
}

// Set the parent SpanContext

///|
pub fn SpanBuilder::parent(
  self : SpanBuilder,
  parent : &SpanContextExtractable,
) -> SpanBuilder {
  { ..self, parent_context: Some(parent.as_span_context()) }
}

///|
pub trait SpanContextExtractable {
  as_span_context(Self) -> SpanContext
}

///|
pub impl SpanContextExtractable for SpanContext with as_span_context(
  self : SpanContext,
) -> SpanContext {
  self
}

///|
pub impl SpanContextExtractable for Span with as_span_context(self : Span) -> SpanContext {
  self.context()
}

// Add an attribute

///|
pub fn SpanBuilder::attribute(
  self : SpanBuilder,
  key : String,
  value : AttributeValue,
) -> SpanBuilder {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, value)
  { ..self, attributes: new_attributes }
}

///|
pub fn SpanBuilder::attributes(
  self : SpanBuilder,
  attributes : Attributes,
) -> SpanBuilder {
  let new_attributes = self.attributes.merge(attributes.map)
  { ..self, attributes: new_attributes }
}

// Set the start time

///|
pub fn SpanBuilder::start_time_ns(
  self : SpanBuilder,
  start_time : Int64,
) -> SpanBuilder {
  { ..self, start_time: Some(start_time) }
}

// Build the Span using the Tracer

///|
pub fn SpanBuilder::start(self : SpanBuilder) -> Span {
  // Generate new trace and span IDs using tracer's config generators
  let trace_id = match self.parent_context {
    Some(parent) => parent.trace_id
    None => (self.tracer_config.trace_id_generator)()
  }
  let span_id = (self.tracer_config.span_id_generator)()
  let parent_span_id = match self.parent_context {
    Some(parent) => Some(parent.span_id)
    None => None
  }

  // Inherit trace flags from parent or default to sampled
  let trace_flags = match self.parent_context {
    Some(parent) => parent.trace_flags
    None => TraceFlags::sampled() // Sampled by default
  }
  let context = SpanContext::new(trace_id, span_id, trace_flags, false)
  let start_time = match self.start_time {
    Some(t) => t
    None => (self.tracer_config.get_current_time_nanos)()
  }
  let mut span = Span::new(
    context,
    self.name,
    self.kind,
    start_time,
    self.resource,
    self.tracer_identifier,
    parent_span_id,
  )

  // Add all attributes from the builder
  self.attributes.each(fn(key, value) {
    span = { ..span, attributes: span.attributes.set(key, value) }
  })
  span
}
