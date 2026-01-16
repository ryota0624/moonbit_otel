// TracerOptions holds configuration for Tracer ID generation

///|
pub struct TracerOptions {
  trace_id_generator : () -> TraceID
  span_id_generator : () -> SpanID
  get_current_time_nanos : () -> Int64
  span_on_start : (Span) -> Unit
  span_on_end : (Span) -> Unit
}

// Create default TracerOptions using built-in generators

///|
pub fn TracerOptions::default(
  rand? : @random.Rand = rand_by_current_time(),
) -> TracerOptions {
  {
    trace_id_generator: () => generate_trace_id(rand),
    span_id_generator: () => generate_span_id(rand),
    get_current_time_nanos: current_time_nanos,
    span_on_start: fn(_) { println("[Tracer] Span started.") },
    span_on_end: fn(_) { println("[Tracer] Span ended.") },
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

///|
pub fn TracerOptions::with_current_time_fn(
  self : TracerOptions,
  time_fn : () -> Int64,
) -> TracerOptions {
  { ..self, get_current_time_nanos: time_fn }
}

///|
pub fn TracerOptions::with_span_on_start(
  self : TracerOptions,
  on_start_fn : (Span) -> Unit,
) -> TracerOptions {
  { ..self, span_on_start: on_start_fn }
}

///|
pub fn TracerOptions::with_span_on_end(
  self : TracerOptions,
  on_end_fn : (Span) -> Unit,
) -> TracerOptions {
  { ..self, span_on_end: on_end_fn }
}

// Tracer is responsible for creating Spans

///|
pub struct Tracer {
  identifier : TracerIdentifier // Identifier for this tracer
  resource : Resource // Resource associated with this tracer
  options : TracerOptions // Options for this tracer
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
) -> Tracer {
  let options = TracerOptions::default()
  { identifier: { name, version }, resource, options }
}

// Create a new Tracer with custom configuration

///|
pub fn Tracer::with_options(
  name : String,
  version : String,
  resource : Resource,
  options : TracerOptions,
) -> Tracer {
  { identifier: { name, version }, resource, options }
}

// Tracer methods for creating spans

///|
fn Tracer::span_builder(self : Tracer, name : String) -> SpanBuilder {
  SpanBuilder::new(name, self.resource, self.identifier, self.options)
}

// Convenience method to start a span directly

///|
pub fn Tracer::start_span(
  self : Tracer,
  name : String,
  kind? : SpanKind,
  parent? : &SpanContextExtractable,
  attributes? : Attributes = Default::default(),
) -> Span {
  let builder = self
    .span_builder(name)
    .kind(kind.unwrap_or_else(() => SpanKind::Unspecified))
    .attributes(attributes)
  let builder_with_parent = match parent {
    Some(p) => builder.parent(p)
    None => builder
  }
  let span = builder_with_parent.start()
  (self.options.span_on_start)(span)
  span
}

///|
/// `run_async` spawn a new coroutine and execute an async function in it
fn run_async(f : async () -> Unit noraise) -> Unit = "%async.run"

///|
pub fn Tracer::span_event(
  self : Tracer,
  name : String,
  attributes? : Attributes = Default::default(),
  event_time? : Int64? = None,
) -> SpanEvent {
  SpanEvent::new(
    name,
    attributes,
    timestamp=event_time.unwrap_or_else(self.options.get_current_time_nanos),
  )
}

///|
/// |
pub struct TracerProvider {
  tracer_factory : (TracerOptions) -> Tracer
  span_processors : Array[&SpanProcessor]
  options : TracerOptions
}

///|
/// get Tracer from TracerProvider
pub fn TracerProvider::tracer(self : TracerProvider) -> Tracer {
  let options = self.options
    .with_span_on_start(fn(span) {
      (self.options.span_on_start)(span)
      for processor in self.span_processors {
        processor.on_span_start(span)
      }
    })
    .with_span_on_end(fn(span) {
      (self.options.span_on_end)(span)
      for processor in self.span_processors {
        processor.on_span_end(span)
      }
    })
  let tracer = (self.tracer_factory)(options)
  tracer
}

///|
pub fn TracerProvider::new(
  name : String,
  version : String,
  resource : Resource,
  options? : TracerOptions = TracerOptions::default(),
  processors? : Array[&SpanProcessor] = [],
) -> TracerProvider {
  TracerProvider::{
    tracer_factory: (opts : TracerOptions) => Tracer::with_options(
      name, version, resource, opts,
    ),
    span_processors: processors,
    options,
  }
}

///|
pub fn TracerProvider::with_span_processors(
  self : TracerProvider,
  processors : Array[&SpanProcessor],
) -> TracerProvider {
  { ..self, span_processors: processors }
}

///|
pub async fn TracerProvider::shutdown(self : TracerProvider) -> Unit {
  for processor in self.span_processors {
    processor.shutdown()
  }
}

///|
pub async fn TracerProvider::force_flush(self : TracerProvider) -> Unit {
  for processor in self.span_processors {
    processor.force_flush()
  }
}

///|
let global_tracer_provider : Ref[TracerProvider] = Ref::new(TracerProvider::{
  tracer_factory: (_ : TracerOptions) => abort(
    "Global TracerProvider is not set.",
  ),
  span_processors: [],
  options: TracerOptions::default(),
})

///|
/// set global TracerProvider
pub fn TracerProvider::set_global(provider : TracerProvider) -> Unit {
  global_tracer_provider.swap(Ref::new(provider))
}

///|
/// get global TracerProvider
pub fn TracerProvider::global() -> TracerProvider {
  global_tracer_provider.val
}
