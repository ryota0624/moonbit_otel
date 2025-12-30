/// TODO: spanを送信する際の形式はprotobufから生成したstructを使うった方が良いので
/// ライブラリとしてのI/Fを整理したSpanと送信フォーマットしてのSpanを分けたい

// TraceID represents a unique 128-bit trace identifier

///|
pub struct TraceID {
  value : String // 32-character hex string
} derive(Eq, Show)

///|
impl ToJson for TraceID with to_json(self : TraceID) -> Json {
  Json::string(self.value)
}

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
} derive(Eq, Show)

///|
impl ToJson for SpanID with to_json(self : SpanID) -> Json {
  Json::string(self.value)
}

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
  Unspecified // Default value. Indicates that the SpanKind is unspecified.
  Internal // Internal operation within an application
  Server // Server-side handling of a synchronous RPC or other remote request
  Client // Client-side of a synchronous RPC or other remote request
  Producer // Parent of an asynchronous request (e.g., message producer)
  Consumer // Child of an asynchronous request (e.g., message consumer)
} derive(Eq, Show)

///|
pub impl ToJson for SpanKind with to_json(self : SpanKind) -> Json {
  let kind_code = match self {
    SpanKind::Unspecified => 0
    SpanKind::Internal => 1
    SpanKind::Server => 2
    SpanKind::Client => 3
    SpanKind::Producer => 4
    SpanKind::Consumer => 5
  }
  Json::number(kind_code.to_double())
}

// SpanStatus represents the status of a finished Span

///|
pub(all) enum SpanStatus {
  Unset // The default status
  Ok // The operation completed successfully
  Error // The operation contains an error
} derive(Eq, Show)

///|
pub impl ToJson for SpanStatus with to_json(self : SpanStatus) -> Json {
  let status_code = match self {
    SpanStatus::Unset => "STATUS_CODE_UNSET"
    SpanStatus::Ok => "STATUS_CODE_OK"
    SpanStatus::Error => "STATUS_CODE_ERROR"
  }
  let message = match self {
    SpanStatus::Unset => "Unset"
    SpanStatus::Ok => "Ok"
    SpanStatus::Error => "Error"
  }
  Json::object({
    "code": Json::string(status_code),
    "message": Json::string(message),
  })
}

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
  traceId : TraceID
  spanId : SpanID
  traceState : String
  parentSpanId : SpanID?
  flags : Int
  name : String
  kind : SpanKind
  startTimeUnixNano : Int64
  endTimeUnixNano : Int64?
  attributes : Attributes
  droppedAttributesCount : Int
  events : Array[SpanEvent]
  droppedEventsCount : Int
  status : SpanStatus
  resource : Resource
  tracer_identifier : TracerIdentifier
}

///|
pub fn hex_to_bytes(hex : String) -> Bytes? {
  // Hex string must have even length (2 chars per byte)
  if hex.length() % 2 != 0 {
    return None
  }
  let byte_count = hex.length() / 2
  let byte_array = Array::new(capacity=byte_count)
  for i = 0; i < byte_count; i = i + 1 {
    let high_char = hex[i * 2].to_int().unsafe_to_char()
    let low_char = hex[i * 2 + 1].to_int().unsafe_to_char()
    match (char_to_int(high_char), char_to_int(low_char)) {
      (Some(high), Some(low)) => {
        let byte_value = high * 16 + low
        byte_array.push(byte_value.to_byte())
      }
      _ => return None
    }
  }
  Some(Bytes::from_array(byte_array))
}

///|
pub fn char_to_int(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
impl ToJson for Span with to_json(self : Span) -> Json {
  // OTLP JSON format requires hex-encoded traceId and spanId (not base64!)
  let json_obj : Map[String, Json] = {}

  // Required fields with hex encoding (lowercase)
  json_obj["traceId"] = Json::string(self.traceId.value)
  json_obj["spanId"] = Json::string(self.spanId.value)

  // Optional parent span ID
  match self.parentSpanId {
    Some(id) => json_obj["parentSpanId"] = Json::string(id.value)
    None => ()
  }

  // Trace state
  if self.traceState != "" {
    json_obj["traceState"] = Json::string(self.traceState)
  }

  // Span name and kind
  json_obj["name"] = Json::string(self.name)
  json_obj["kind"] = @trace.Span_SpanKind::to_string(
    match self.kind {
      SpanKind::Unspecified => @trace.Span_SpanKind::SPAN_KIND_UNSPECIFIED
      SpanKind::Internal => @trace.Span_SpanKind::SPAN_KIND_INTERNAL
      SpanKind::Server => @trace.Span_SpanKind::SPAN_KIND_SERVER
      SpanKind::Client => @trace.Span_SpanKind::SPAN_KIND_CLIENT
      SpanKind::Producer => @trace.Span_SpanKind::SPAN_KIND_PRODUCER
      SpanKind::Consumer => @trace.Span_SpanKind::SPAN_KIND_CONSUMER
    },
  ).to_json()

  // Timestamps as strings
  json_obj["startTimeUnixNano"] = Json::string(
    self.startTimeUnixNano.to_string(),
  )
  match self.endTimeUnixNano {
    Some(end) => json_obj["endTimeUnixNano"] = Json::string(end.to_string())
    None => ()
  }

  // Flags
  if self.flags != 0 {
    json_obj["flags"] = Json::number(self.flags.to_double())
  }
  json_obj["status"] = self.status.to_json()
  Json::object(json_obj)
}

///|
pub fn Span::to_protobuf(self : Span) -> @trace.Span {
  let p_span = @trace.Span::default()
  p_span.trace_id = hex_to_bytes(self.traceId.value).unwrap()
  p_span.span_id = hex_to_bytes(self.spanId.value).unwrap()

  // p_span.span_id = self.spanId.value
  match self.parentSpanId {
    Some(id) => p_span.parent_span_id = hex_to_bytes(id.value).unwrap()
    None => ()
  }
  p_span.trace_state = self.traceState
  p_span.name = self.name
  p_span.kind = match self.kind {
    SpanKind::Unspecified => @trace.Span_SpanKind::SPAN_KIND_UNSPECIFIED
    SpanKind::Internal => @trace.Span_SpanKind::SPAN_KIND_INTERNAL
    SpanKind::Server => @trace.Span_SpanKind::SPAN_KIND_SERVER
    SpanKind::Client => @trace.Span_SpanKind::SPAN_KIND_CLIENT
    SpanKind::Producer => @trace.Span_SpanKind::SPAN_KIND_PRODUCER
    SpanKind::Consumer => @trace.Span_SpanKind::SPAN_KIND_CONSUMER
  }
  p_span.start_time_unix_nano = self.startTimeUnixNano.reinterpret_as_uint64()
  match self.endTimeUnixNano {
    Some(end) => p_span.end_time_unix_nano = end.reinterpret_as_uint64()
    None => ()
  }
  p_span.flags = self.flags.reinterpret_as_uint()
  p_span.status = match self.status {
    SpanStatus::Unset =>
      @trace.Status::{
        code: @trace.Status_StatusCode::STATUS_CODE_UNSET,
        message: "unset",
      }
    SpanStatus::Ok =>
      @trace.Status::{
        code: @trace.Status_StatusCode::STATUS_CODE_OK,
        message: "ok",
      }
    SpanStatus::Error =>
      @trace.Status::{
        code: @trace.Status_StatusCode::STATUS_CODE_ERROR,
        message: "error",
      }
  }

  // Serialize attributes
  p_span.attributes = []
  self.attributes.map.each(fn(key, value) {
    let any_value = value.to_protobuf()
    let key_value = @otel_common.KeyValue::{ key, value: any_value }
    p_span.attributes.push(key_value)
  })

  // Serialize events
  p_span.events = []
  for event in self.events {
    let p_event = @trace.Span_Event::default()
    p_event.time_unix_nano = event.timestamp.reinterpret_as_uint64()
    p_event.name = event.name
    p_event.attributes = []
    event.attributes.each(fn(key, value) {
      let any_value = value.to_protobuf()
      let key_value = @otel_common.KeyValue::{ key, value: any_value }
      p_event.attributes.push(key_value)
    })
    p_span.events.push(p_event)
  }
  p_span
}

// Create a new Span

///|
pub fn Span::new(
  context : SpanContext,
  name : String,
  kind : SpanKind,
  start_time : Int64,
  resource : Resource,
  tracer_identifier : TracerIdentifier,
  parent_span_id : SpanID?,
) -> Span {
  {
    traceId: context.trace_id,
    spanId: context.span_id,
    traceState: "",
    parentSpanId: parent_span_id,
    flags: context.trace_flags,
    name,
    kind,
    startTimeUnixNano: start_time,
    endTimeUnixNano: None,
    status: SpanStatus::Unset,
    attributes: Attributes::new(),
    droppedAttributesCount: 0,
    events: [],
    droppedEventsCount: 0,
    resource,
    tracer_identifier,
  }
}

// Add an attribute to the Span

///|
pub fn Span::set_attribute(
  self : Span,
  key : String,
  value : AttributeValue,
) -> Span {
  let new_attributes = self.attributes.set(key, value)
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
  { ..self, endTimeUnixNano: Some(end_time) }
}

// Check if the Span has ended

///|
pub fn Span::is_ended(self : Span) -> Bool {
  self.endTimeUnixNano is Some(_)
}

// Get the duration of the Span in nanoseconds (returns None if not ended)

///|
pub fn Span::duration(self : Span) -> Int64? {
  match self.endTimeUnixNano {
    Some(end) => Some(end - self.startTimeUnixNano)
    None => None
  }
}

///|
#cfg(target="js")
extern "js" fn js_date_now_double() -> Double =
  #|() => Date.now()

///|
#cfg(target="js")
pub fn get_current_time_ms() -> Int64 {
  js_date_now_double().to_int64()
}

///|
#cfg(target="native")
pub fn get_current_time_ms() -> Int64 {
  @async.now()
}

// Helper function to generate a random hex string of given length
// Note: Uses current timestamp as seed for randomness

///|
pub fn rand_by_current_time() -> @random.Rand {
  // Create a 32-byte seed from timestamp to ensure different values on each call
  let timestamp = get_current_time_ms()
  let seed_array = Array::new(capacity=32)
  // Fill seed with timestamp bytes (repeat as needed)
  for i = 0; i < 32; i = i + 1 {
    let shift = i % 8 * 8
    let timestamp_int = timestamp.to_int()
    let byte_val = ((timestamp_int >> shift) & 0xFF).to_byte()
    seed_array.push(byte_val)
  }
  let seed_bytes = Bytes::from_array(seed_array)
  @random.Rand::chacha8(seed=seed_bytes)
}

///|
fn random_hex(length : Int, rand : @random.Rand) -> String {
  let chars = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let mut result = ""
  for i = 0; i < length; i = i + 1 {
    let index = rand.int(limit=16)
    result = result + chars[index].to_string()
  }
  result
}

///|
test "random_hex generates hex string of correct length" {
  let hex16 = random_hex(16, rand_by_current_time())
  assert_eq(hex16.length(), 16)
  let hex32 = random_hex(32, rand_by_current_time())
  assert_eq(hex32.length(), 32)
  // let h_s = hex_to_bytes(hex16).unwrap()
  // println(@encoding/utf8.decode(h_s))
}

// Generate a new TraceID (128-bit, 32 hex characters)

///|
pub fn generate_trace_id(rand : @random.Rand) -> TraceID {
  TraceID::new(random_hex(32, rand))
}

// Generate a new SpanID (64-bit, 16 hex characters)

///|
pub fn generate_span_id(rand : @random.Rand) -> SpanID {
  SpanID::new(random_hex(16, rand))
}
