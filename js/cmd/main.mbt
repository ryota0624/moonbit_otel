///|
async fn main {
  let provider = @lib.http_client_provider()
  let adaptor = @otel.HttpSendAdaptor::new(
    provider,
    endpoint="http://192.168.0.9:4318/v1/traces",
  )
  @cmd_main.run_example(
    @otel.OTLPExporterConfig::default(@otel.Http(adaptor)).enable_debug_log(
      print=println,
    ),
    print=println,
  )
}
