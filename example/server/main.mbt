///|
// docker run --rm --name jaeger \
// -p 16686:16686 \
// -p 4317:4317 \
// -p 4318:4318 \
// -p 5778:5778 \
// -p 9411:9411 \
// cr.jaegertracing.io/jaegertracing/jaeger:2.13.0
// moon run --target native .
// repeat 10 curl -v http://localhost:8000
#cfg(target="native")
async fn main {
  let protobuf_provider = @moonbit_otel.protobuf_http_client_provider()
  let otlp_config = @moonbit_otel.OTLPExporterOptions::http_protobuf(
    protobuf_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)
  let otlp_exporter = @moonbit_otel.OTLPExporter::new(otlp_config)
  let resource = @moonbit_otel.Resource::empty()
    .with_string(@moonbit_otel.service_name, "demo-service")
    .with_string(@moonbit_otel.service_version, "1.0.0")
    .with_string("environment", "development")
  let processor_options = @moonbit_otel.BatchSpanProcessorOptions::default().enable_debug_log(println)
  let processor = @moonbit_otel.BatchSpanProcessor::new(
    otlp_exporter,
    options=processor_options,
  )
  let trace_provider = @moonbit_otel.TracerProvider::new(
    "demo-trace", "1.0.0", resource,
  ).with_span_processors([processor])
  @moonbit_otel.TracerProvider::set_global(trace_provider)
  let _ = @async.with_task_group(fn(group) {
    group.add_defer(async fn() { otlp_exporter.shutdown() })
    group.spawn_bg(async fn() { processor.start() })
    // Start HTTP server to receive requests
    group.spawn_bg(async fn() {
      let server = @http.Server::new(@socket.Addr::parse("0.0.0.0:8000"))
      println("Server is running on http://localhost:8000")
      server.run_forever(fn(req, _, conn) {
        println("Received request: " + req.path)
        send_span(req)
        println("Sent span for request: " + req.path)
        conn.send_response(200, "OK")
        conn.write(@encoding/utf8.encode("Hello, World!\n"))
        conn.flush()
        conn.end_response()
      })
      ()
    })
  })
  println("Server has stopped.")
}

///|
#cfg(not(target="native"))
fn main {
  println("This example is only supported on native target.")
  panic()
}

///|
#cfg(target="native")
async fn send_span(req : @http.Request) -> Unit noraise {
  let tracer = @moonbit_otel.TracerProvider::global().tracer()
  println("Creating span for request: " + req.path)
  let span = tracer.start_span(
    "http-request",
    kind=@moonbit_otel.SpanKind::Server,
    attributes=@moonbit_otel.Attributes::default()
      .with_string("http.method", req.meth.to_string())
      .with_string("http.path", req.path),
  )
  // .parent(parent_context)
  let _ = span.set_status(@moonbit_otel.SpanStatus::Ok).end()
  ()
}
