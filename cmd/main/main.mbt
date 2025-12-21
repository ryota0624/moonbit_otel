///|
fn main {
  // Resourceの作成
  let resource = @lib.Resource::empty()
    .with_string(@lib.service_name, "demo-service")
    .with_string(@lib.service_version, "1.0.0")
    .with_string("environment", "development")

  // Tracerの作成
  let tracer = @lib.Tracer::new("demo-tracer", "1.0.0", resource)

  // 親Spanの作成
  let parent_span = tracer
    .span_builder("http-request")
    .with_kind(@lib.SpanKind::Server)
    .with_attribute("http.method", @lib.AttributeValue::String("GET"))
    .with_attribute("http.url", @lib.AttributeValue::String("/api/users"))
    .with_attribute("http.status_code", @lib.AttributeValue::Int(200))
    .with_start_time(1000000L)
    .start(tracer)

  // イベントの追加
  let event = @lib.SpanEvent::new("request_received", 1000500L, Map::new())
  let parent_span = parent_span.add_event(event)

  // 子Spanの作成
  let child_span = tracer
    .span_builder("database-query")
    .with_kind(@lib.SpanKind::Client)
    .with_parent(parent_span.context)
    .with_attribute("db.system", @lib.AttributeValue::String("postgresql"))
    .with_attribute(
      "db.statement",
      @lib.AttributeValue::String("SELECT * FROM users"),
    )
    .with_start_time(1001000L)
    .start(tracer)
    .set_status(@lib.SpanStatus::Ok)
    .end(1003000L)

  // 親Spanを終了
  let parent_span = parent_span.set_status(@lib.SpanStatus::Ok).end(1005000L)

  // Exporterの作成
  let exporter = @lib.ConsoleExporter::new()

  // Spanをエクスポート
  println("=== Exporting Spans ===")
  exporter.export_spans([child_span, parent_span])

  // Exporterをシャットダウン
  exporter.shutdown()
}
