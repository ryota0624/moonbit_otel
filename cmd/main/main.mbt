///|
#cfg(target="js")
async fn main {
  // Using JSON format
  let json_provider = @otel_js.json_http_client_provider()
  let json_config = @otel.OTLPExporterConfig::http_json(
    json_provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Using Protobuf format
  let protobuf_provider = @otel_js.protobuf_http_client_provider()
  let protobuf_config = @otel.OTLPExporterConfig::http_protobuf(
    protobuf_provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Run example with Protobuf (you can change to json_config if needed)
  run_example(protobuf_config, print=println)
}

///|
#cfg(target="native")
async fn main {
  // Using JSON format
  let json_provider = @otel_native.json_http_client_provider()
  let json_config = @otel.OTLPExporterConfig::http_json(
    json_provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Using Protobuf format
  let protobuf_provider = @otel_native.protobuf_http_client_provider()
  let protobuf_config = @otel.OTLPExporterConfig::http_protobuf(
    protobuf_provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  ).enable_debug_log(print=println)

  // Run example with Protobuf (you can change to json_config if needed)
  run_example(protobuf_config, print=println)
}

///|
fn current_time_nanos() -> Int64 {
  @otel.get_current_time_ms() * 1_000_000
}

///|
pub async fn run_example(
  otlp_config : @otel.OTLPExporterConfig,
  print~ : (String) -> Unit,
) -> Unit {
  // Resourceの作成
  let resource = @otel.Resource::empty()
    .with_string(@otel.service_name, "demo-service")
    .with_string(@otel.service_version, "1.0.0")
    .with_string("environment", "development")

  // Tracerの作成
  let tracer = @otel.Tracer::new(
    "demo-tracer",
    "1.0.0",
    resource,
    @otel.rand_by_current_time(),
  )

  // 親Spanの作成
  let parent_span = tracer
    .span_builder("http-request")
    .with_kind(@otel.SpanKind::Server)
    .with_attribute("http.method", @otel.AttributeValue::String("GET"))
    .with_attribute("http.url", @otel.AttributeValue::String("/api/users"))
    .with_attribute("http.status_code", @otel.AttributeValue::Int(200))
    .with_start_time(current_time_nanos())
    .start(tracer)

  // イベントの追加
  let event = @otel.SpanEvent::new(
    "request_received",
    current_time_nanos(),
    Map::new(),
  )
  let parent_span = parent_span.add_event(event)

  // 子Spanの作成
  let parent_context = @otel.SpanContext::new(
    parent_span.traceId,
    parent_span.spanId,
    parent_span.flags,
    false,
  )
  let child_span = tracer
    .span_builder("database-query")
    .with_kind(@otel.SpanKind::Client)
    .with_parent(parent_context)
    .with_attribute("db.system", @otel.AttributeValue::String("postgresql"))
    .with_attribute(
      "db.statement",
      @otel.AttributeValue::String("SELECT * FROM users"),
    )
    .with_start_time(current_time_nanos())
    .start(tracer)
    .set_status(@otel.SpanStatus::Ok)
    .end(current_time_nanos())

  // 親Spanを終了
  let parent_span = parent_span
    .set_status(@otel.SpanStatus::Ok)
    .end(current_time_nanos())

  // ConsoleExporterの作成
  let console_exporter = @otel.PrettyPrintExporter::new(print)

  // Spanをコンソールにエクスポート
  console_exporter.export_spans([parent_span, child_span])

  // ConsoleExporterをシャットダウン
  console_exporter.shutdown()

  // OTLPExporterの作成
  let otlp_exporter : &@otel.SpanExporter = @otel.OTLPExporter::new(otlp_config)
  // Spanを OTLP Collectorにエクスポート
  otlp_exporter.export_spans([parent_span, child_span])

  // OTLPExporterをシャットダウン
  otlp_exporter.shutdown()
}
