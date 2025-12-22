// TraceID represents a unique 128-bit trace identifier

///|
pub struct TraceID {
  value : String // 32-character hex string
} derive(Eq, Show, ToJson)

// Create a new TraceID

///|
pub fn TraceID::new(value : String) -> TraceID {
  { value, }
}

// Get the string value of TraceID

///|
pub fn TraceID::to_string(self : TraceID) -> String {
  self.value
}

// Check if TraceID is valid (non-zero)

///|
pub fn TraceID::is_valid(self : TraceID) -> Bool {
  self.value != "00000000000000000000000000000000"
}

// SpanID represents a unique 64-bit span identifier

///|
pub struct SpanID {
  value : String // 16-character hex string
} derive(Eq, Show, ToJson)

// Create a new SpanID

///|
pub fn SpanID::new(value : String) -> SpanID {
  { value, }
}

// Get the string value of SpanID

///|
pub fn SpanID::to_string(self : SpanID) -> String {
  self.value
}

// Check if SpanID is valid (non-zero)

///|
pub fn SpanID::is_valid(self : SpanID) -> Bool {
  self.value != "0000000000000000"
}

// SpanContext represents the portion of a Span which must be serialized and 
// propagated along side of a distributed context.

///|
pub struct SpanContext {
  trace_id : TraceID
  span_id : SpanID
  trace_flags : Int
  is_remote : Bool
} derive(ToJson)

// Create a new SpanContext

///|
pub fn SpanContext::new(
  trace_id : TraceID,
  span_id : SpanID,
  trace_flags : Int,
  is_remote : Bool,
) -> SpanContext {
  { trace_id, span_id, trace_flags, is_remote }
}

// Check if the span context is valid (non-zero IDs)

///|
pub fn SpanContext::is_valid(self : SpanContext) -> Bool {
  self.trace_id.is_valid() && self.span_id.is_valid()
}

// Check if the span is sampled

///|
pub fn SpanContext::is_sampled(self : SpanContext) -> Bool {
  (self.trace_flags & 0x01) != 0
}

// SpanKind describes the relationship between the Span, its parents, and its children

///|
pub(all) enum SpanKind {
  Internal // Internal operation within an application
  Server // Server-side handling of a synchronous RPC or other remote request
  Client // Client-side of a synchronous RPC or other remote request
  Producer // Parent of an asynchronous request (e.g., message producer)
  Consumer // Child of an asynchronous request (e.g., message consumer)
} derive(Eq, Show, ToJson)

// SpanStatus represents the status of a finished Span

///|
pub(all) enum SpanStatus {
  Unset // The default status
  Ok // The operation completed successfully
  Error // The operation contains an error
} derive(Eq, Show, ToJson)

// SpanEvent represents a single event within a Span

///|
pub struct SpanEvent {
  name : String
  timestamp : Int64 // Unix timestamp in nanoseconds
  attributes : Map[String, AttributeValue]
} derive(ToJson)

// Create a new SpanEvent

///|
pub fn SpanEvent::new(
  name : String,
  timestamp : Int64,
  attributes : Map[String, AttributeValue],
) -> SpanEvent {
  { name, timestamp, attributes }
}

// Span represents a single operation within a trace

///|
pub struct Span {
  context : SpanContext
  name : String
  kind : SpanKind
  start_time : Int64
  end_time : Int64?
  status : SpanStatus
  attributes : Map[String, AttributeValue]
  events : Array[SpanEvent]
  parent_span_id : SpanID?
  resource : Resource
} derive(ToJson)

// Create a new Span

///|
pub fn Span::new(
  context : SpanContext,
  name : String,
  kind : SpanKind,
  start_time : Int64,
  resource : Resource,
  parent_span_id : SpanID?,
) -> Span {
  {
    context,
    name,
    kind,
    start_time,
    end_time: None,
    status: SpanStatus::Unset,
    attributes: Map::new(),
    events: [],
    parent_span_id,
    resource,
  }
}

// Add an attribute to the Span

///|
pub fn Span::set_attribute(
  self : Span,
  key : String,
  value : AttributeValue,
) -> Span {
  let new_attributes = self.attributes.copy()
  new_attributes.set(key, value)
  { ..self, attributes: new_attributes }
}

// Add an event to the Span

///|
pub fn Span::add_event(self : Span, event : SpanEvent) -> Span {
  let new_events = Array::new(capacity=self.events.length() + 1)
  for i = 0; i < self.events.length(); i = i + 1 {
    new_events.push(self.events[i])
  }
  new_events.push(event)
  { ..self, events: new_events }
}

// Set the status of the Span

///|
pub fn Span::set_status(self : Span, status : SpanStatus) -> Span {
  { ..self, status, }
}

// End the Span with the given timestamp

///|
pub fn Span::end(self : Span, end_time : Int64) -> Span {
  { ..self, end_time: Some(end_time) }
}

// Check if the Span has ended

///|
pub fn Span::is_ended(self : Span) -> Bool {
  self.end_time is Some(_)
}

// Get the duration of the Span in nanoseconds (returns None if not ended)

///|
pub fn Span::duration(self : Span) -> Int64? {
  match self.end_time {
    Some(end) => Some(end - self.start_time)
    None => None
  }
}

// Helper function to generate a random hex string of given length

///|
fn random_hex(length : Int) -> String {
  let chars = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let mut result = ""
  for i = 0; i < length; i = i + 1 {
    // Simple pseudo-random generation (not cryptographically secure)
    // In production, this should use a proper random number generator
    let index = (i * 7 + 13) % 16
    result = result + chars[index]
  }
  result
}

// Generate a new TraceID (128-bit, 32 hex characters)

///|
pub fn generate_trace_id() -> TraceID {
  TraceID::new(random_hex(32))
}

// Generate a new SpanID (64-bit, 16 hex characters)

///|
pub fn generate_span_id() -> SpanID {
  SpanID::new(random_hex(16))
}
