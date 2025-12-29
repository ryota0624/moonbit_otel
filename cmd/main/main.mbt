///|
#cfg(target="js")
async fn main {
  let provider = @otel_js.http_client_provider()
  let adaptor = @otel.HttpSendAdaptor::new(
    provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  )
  run_example(
    @otel.OTLPExporterConfig::default(@otel.Http(adaptor)).enable_debug_log(
      print=println,
    ),
    print=println,
  )
}

///|
#cfg(target="native")
async fn main {
  let provider = @otel_native.http_client_provider()
  let adaptor = @otel.HttpSendAdaptor::new(
    provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  )
  run_example(
    @otel.OTLPExporterConfig::default(@otel.Http(adaptor)).enable_debug_log(
      print=println,
    ),
    print=println,
  )
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
    .with_start_time(@otel.get_current_time_ms())
    .start(tracer)

  // イベントの追加
  let event = @otel.SpanEvent::new(
    "request_received",
    @otel.get_current_time_ms(),
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
    .with_start_time(@otel.get_current_time_ms())
    .start(tracer)
    .set_status(@otel.SpanStatus::Ok)
    .end(@otel.get_current_time_ms())

  // 親Spanを終了
  let parent_span = parent_span
    .set_status(@otel.SpanStatus::Ok)
    .end(@otel.get_current_time_ms())

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
