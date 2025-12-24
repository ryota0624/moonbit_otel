// OTLP (OpenTelemetry Protocol) Exporter
// Sends spans to an OpenTelemetry Collector via HTTP+JSON

///|
pub(open) trait HttpClientFactory {
  async create_client(Self) -> &HttpClient
}

///|
pub(all) struct HttpSendAdaptor {
  client_factory : &HttpClientFactory
  endpoint : String
  headers : Map[String, String]
}

///|
pub fn HttpSendAdaptor::new(
  client_factory : &HttpClientFactory,
  endpoint? : String = "http://localhost:4318/v1/traces",
  headers? : Map[String, String] = {},
) -> HttpSendAdaptor {
  { client_factory, endpoint, headers }
}

///|
pub(all) struct StdoutSendAdaptor {
  print : (String) -> Unit
}

///|
pub fn StdoutSendAdaptor::new(print : (String) -> Unit) -> StdoutSendAdaptor {
  StdoutSendAdaptor::{ print, }
}

///|
pub(all) enum ExportAdapter {
  Http(HttpSendAdaptor)
  Stdout(StdoutSendAdaptor)
}

///|
pub struct OTLPExporterConfig {
  logger_factory : () -> InternalLogger
  export_adapter : ExportAdapter
}

///|
pub struct OTLPExporter {
  config : OTLPExporterConfig
  priv logger : InternalLogger
  priv export_adapter : ExportAdapter
}

///|
pub(open) trait HttpClient {
  async http_post_json(
    Self,
    url : String,
    body : String,
    headers : Map[String, String],
  ) -> Result[HttpResponse, HttpError]
}

// Create default OTLP exporter configuration

///|
pub fn OTLPExporterConfig::default(
  export_adapter : ExportAdapter,
) -> OTLPExporterConfig {
  { logger_factory: () => InternalLogger::none(), export_adapter }
}
// Set the endpoint URL
// Set the timeout in milliseconds

///|
pub fn OTLPExporterConfig::enable_debug_log(
  self : OTLPExporterConfig,
  print~ : (&Show) -> Unit,
) -> OTLPExporterConfig {
  { ..self, logger_factory: () => InternalLogger::{ print_fn: print } }
}

// Create a new OTLP exporter with the given configuration

///|
pub fn OTLPExporter::new(config : OTLPExporterConfig) -> OTLPExporter {
  {
    config,
    logger: (config.logger_factory)(),
    export_adapter: config.export_adapter,
  }
}

// Explicit implementation of SpanExporter trait for OTLPExporter

///|
pub async fn OTLPExporter::export_spans(
  self : OTLPExporter,
  spans : Array[Span],
) -> Unit {
  if spans.length() == 0 {
    return
  }

  // Convert spans to OTLP JSON format
  let json_body = spans_to_resource_spans_json(spans)
  let adaptor = self.export_adapter
  match adaptor {
    ExportAdapter::Http(http_adaptor) => {
      let client = http_adaptor.client_factory.create_client()
      self.export_spans_by_http_client(json_body, client, http_adaptor, spans)
    }
    ExportAdapter::Stdout(stdout_adaptor) => (stdout_adaptor.print)(json_body)
  }
}

///|
pub async fn OTLPExporter::export_spans_by_http_client(
  self : OTLPExporter,
  json_body : String,
  http_client : &HttpClient,
  http_adaptor : HttpSendAdaptor,
  spans : Array[Span],
) -> Unit {
  try {
    let result = http_client.http_post_json(
      http_adaptor.endpoint,
      json_body,
      http_adaptor.headers.merge({ "Content-Type": "application/json" }),
    )
    match result {
      Ok(response) =>
        if response.status_code >= 200 && response.status_code < 300 {
          // Success - span exported successfully
          self.logger.log(
            "[OTLP] Exported " + spans.length().to_string() + " span(s)",
          )
        } else {
          // HTTP error response
          self.logger.log(
            "[OTLP] Export failed with status " +
            response.status_code.to_string() +
            ": " +
            response.body,
          )
        }
      Err(error) =>
        // Network or transport error
        self.logger.log("[OTLP] Export error: " + error.to_string())
    }
  } catch {
    err => self.logger.log("[OTLP] HTTP export error: " + err.to_string())
  }
}

// Explicit implementation of SpanExporter trait for OTLPExporter

///|
pub fn OTLPExporter::shutdown(self : OTLPExporter) -> Unit {
  self.logger.log("[OTLP] OTLPExporter shutdown")
}

///|
pub impl SpanExporter for OTLPExporter with export_spans(
  self : OTLPExporter,
  spans : Array[Span],
) -> Unit {
  self.logger.log("[OTLP] Starting export of spans asynchronously")
  self.export_spans(spans) catch {
    err => self.logger.log("[OTLP] Error during export: " + err.to_string())
  }
}

///|
///[]
pub impl SpanExporter for OTLPExporter with shutdown(self : OTLPExporter) -> Unit {
  self.shutdown()
}
