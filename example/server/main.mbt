///|
async fn main {
  let protobuf_provider = @otel_native.protobuf_http_client_provider()
  let otlp_config = @moonbit_otel.OTLPExporterOptions::http_protobuf(
    protobuf_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)
  let otlp_exporter = @moonbit_otel.OTLPExporter::new(otlp_config).enable_batch_export()
  let resource = @moonbit_otel.Resource::empty()
    .with_string(@moonbit_otel.service_name, "demo-service")
    .with_string(@moonbit_otel.service_version, "1.0.0")
    .with_string("environment", "development")
  let tracer = @moonbit_otel.Tracer::new(
    "demo-tracer",
    "1.0.0",
    resource,
    @moonbit_otel.rand_by_current_time(),
  )
  let _ = @async.with_task_group(fn(group) {
    group.add_defer(async fn() { otlp_exporter.shutdown() })
    group.spawn_bg(async fn() { otlp_exporter.start() })
    // Start HTTP server to receive requests
    group.spawn_bg(async fn() {
      let server = @http.Server::new(@socket.Addr::parse("0.0.0.0:8000"))
      println("Server is running on http://localhost:8000")
      server.run_forever(fn(req, _, conn) {
        println("Received request: " + req.path)
        send_span(req, tracer, otlp_exporter)
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
async fn send_span(
  req : @http.Request,
  tracer : @moonbit_otel.Tracer,
  exporeter : &@moonbit_otel.SpanExporter,
) -> Unit noraise {
  println("Creating span for request: " + req.path)
  let span = tracer
    .span_builder("http-request")
    .kind(@moonbit_otel.SpanKind::Server)
    // .parent(parent_context)
    .attribute(
      "http.method",
      @moonbit_otel.AttributeValue::String(req.meth.to_string()),
    )
    .attribute("http.path", @moonbit_otel.AttributeValue::String(req.path))
    .start()
  let span = span.set_status(@moonbit_otel.SpanStatus::Ok).end()
  exporeter.export_spans([span]) catch {
    err => println("[Error] Failed to export spans: " + err.to_string())
  }
  // @async.with_task_group(fn(group) {
  //   println("Spawning background task to export span for request: " + req.path)
  //   group.spawn_bg(no_wait=true, fn() {
  //     println("Exporting span...")
  //     exporeter.export_spans([span]) catch {
  //       err => println("[Error] Failed to export spans: " + err.to_string())
  //     }
  //     println("Span exported.")
  //   })
  // }) catch {
  //   _ => println("[Error] Failed to process request.")
  // }
  ()
}
