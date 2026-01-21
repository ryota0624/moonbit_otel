// OpenTelemetry OTLP Exporter Example
//
// docker run --rm --name jaeger \
// -p 16686:16686 \
// -p 4317:4317 \
// -p 4318:4318 \
// -p 5778:5778 \
// -p 9411:9411 \
// cr.jaegertracing.io/jaegertracing/jaeger:2.13.0
//
// moon run --target js cmd/main/main.mbt

///|
#cfg(target="js")
async fn main {
  // Using JSON format
  let json_provider = @otel.json_http_client_provider()
  let json_config = @otel.OTLPExporterOptions::http_json(
    json_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)
  run_example(json_config, print=println)

  // Using Protobuf format
  let protobuf_provider = @otel.protobuf_http_client_provider()
  let protobuf_config = @otel.OTLPExporterOptions::http_protobuf(
    protobuf_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Run example with Protobuf (you can change to json_config if needed)
  run_example(protobuf_config, print=println)
}

///|
#cfg(target="native")
async fn main {
  // Using JSON format
  let json_provider = @otel.json_http_client_provider()
  let json_config = @otel.OTLPExporterOptions::http_json(
    json_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)
  run_example(json_config, print=println)

  // Using Protobuf format
  let protobuf_provider = @otel.protobuf_http_client_provider()
  let protobuf_config = @otel.OTLPExporterOptions::http_protobuf(
    protobuf_provider,
    endpoint="http://localhost:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Run example with Protobuf (you can change to json_config if needed)
  run_example(protobuf_config, print=println)
}

///|
pub async fn run_example(
  otlp_config : @otel.OTLPExporterOptions,
  print~ : (String) -> Unit,
) -> Unit {
  // Resourceの作成
  let resource = @otel.Resource::empty()
    .with_string(@otel.service_name, "demo-service")
    .with_string(@otel.service_version, "1.0.0")
    .with_string("environment", "development")

  // Tracerの作成
  let tracer = @otel.Tracer::new("demo-tracer", "1.0.0", resource)

  // 親Spanの作成
  let parent_span = tracer.start_span(
    "http-request",
    kind=@otel.SpanKind::Server,
    attributes=@otel.Attributes::default()
      .with_string("http.method", "GET")
      .with_string("http.url", "/api/users")
      .with_int("http.status_code", 200)
      .with_string(
        "http.user_agent", "Mozilla/5.0 (compatible; DemoClient/1.0)",
      ),
  )

  // イベントの追加
  let event = @otel.SpanEvent::new(
    "request_received",
    @otel.Attributes::default().with_string("some_key", "okay"),
    timestamp=@otel.current_time_nanos(),
  )
  let parent_span = parent_span.add_event(event)

  // 子Spanの作成
  let parent_context = parent_span.context()
  let child_span = tracer
    .start_span(
      "database-query",
      parent=parent_context,
      kind=@otel.SpanKind::Client,
      attributes=@otel.Attributes::default().with_string(
        "db.system", "postgresql",
      ),
    )
    .set_status(@otel.SpanStatus::Ok)
    .end(end_time_ns=@otel.current_time_nanos() + 5000000)
  let child_span = child_span.add_event(
    tracer.span_event(
      "query_executed",
      attributes=@otel.Attributes::default().with_int("rows_returned", 42),
    ),
  )

  // 親Spanを終了
  let parent_span = parent_span
    .set_status(@otel.SpanStatus::Ok)
    .end(end_time_ns=@otel.current_time_nanos() + 10000000)

  // link用の別Spanを作成
  let other_span = tracer
    .start_span("related-operation")
    .set_status(@otel.SpanStatus::Ok)
    .end()
  let other_span = other_span.add_link(child_span.context())

  // ConsoleExporterの作成
  let console_exporter = @otel.PrettyPrintExporter::new(print)

  // Spanをコンソールにエクスポート
  console_exporter.export_spans([parent_span, child_span, other_span])

  // ConsoleExporterをシャットダウン
  console_exporter.shutdown()

  // OTLPExporterの作成
  let otlp_exporter : &@otel.SpanExporter = @otel.OTLPExporter::new(otlp_config)
  // Spanを OTLP Collectorにエクスポート
  otlp_exporter.export_spans([parent_span, child_span, other_span])

  // OTLPExporterをシャットダウン
  otlp_exporter.shutdown()
}
