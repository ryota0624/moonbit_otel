///|
async fn main {
  let factory = @lib.http_client_factory()
  @cmd_main.run_example(
    @otel.OTLPExporterConfig::default(factory).with_endpoint(
      "http://192.168.0.9:4318/v1/traces",
    ),
  )
}
