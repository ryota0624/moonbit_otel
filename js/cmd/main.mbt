///|
async fn main {
  let factory = @lib.http_client_factory()
  let adaptor = @otel.HttpSendAdaptor::new(
    factory,
    endpoint="http://192.168.0.9:4318/v1/traces",
  )
  @cmd_main.run_example(
    @otel.OTLPExporterConfig::default(@otel.Http(adaptor)).enable_debug_log(
      print=println,
    ),
    print=println,
  )
}
