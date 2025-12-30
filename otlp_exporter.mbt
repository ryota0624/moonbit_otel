// OTLP (OpenTelemetry Protocol) Exporter
// Sends spans to an OpenTelemetry Collector via HTTP+JSON

///|
pub(open) trait JsonHttpClientProvider {
  get_json_client(Self) -> &JsonHttpClient
}

///|
pub(open) trait ProtobufHttpClientProvider {
  get_protobuf_client(Self) -> &ProtobufHttpClient
}

///|
pub(all) struct HttpJsonSendAdaptor {
  client_provider : &JsonHttpClientProvider
  endpoint : String
  headers : Map[String, String]
}

///|
pub fn HttpJsonSendAdaptor::new(
  client_provider : &JsonHttpClientProvider,
  endpoint? : String = "http://localhost:4318/v1/traces",
  headers? : Map[String, String] = {},
) -> HttpJsonSendAdaptor {
  { client_provider, endpoint, headers }
}

///|
pub(all) struct HttpProtobufSendAdaptor {
  client_provider : &ProtobufHttpClientProvider
  endpoint : String
  headers : Map[String, String]
}

///|
pub fn HttpProtobufSendAdaptor::new(
  client_provider : &ProtobufHttpClientProvider,
  endpoint? : String = "http://localhost:4318/v1/traces",
  headers? : Map[String, String] = {},
) -> HttpProtobufSendAdaptor {
  { client_provider, endpoint, headers }
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
  HttpJson(HttpJsonSendAdaptor)
  HttpProtobuf(HttpProtobufSendAdaptor)
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
pub(open) trait JsonHttpClient {
  async http_post_json(
    Self,
    url : String,
    body : String,
    headers : Map[String, String],
  ) -> Result[HttpResponse, HttpError]
}

///|
pub(open) trait ProtobufHttpClient {
  async http_post_protobuf(
    Self,
    url : String,
    body : Bytes,
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

///|
pub fn OTLPExporterConfig::stdout(
  print : (String) -> Unit,
) -> OTLPExporterConfig {
  OTLPExporterConfig::default(
    ExportAdapter::Stdout(StdoutSendAdaptor::new(print)),
  )
}

///|
pub fn OTLPExporterConfig::http_json(
  client_provider : &JsonHttpClientProvider,
  endpoint? : String = "http://localhost:4318/v1/traces",
  headers? : Map[String, String] = {},
) -> OTLPExporterConfig {
  OTLPExporterConfig::default(
    ExportAdapter::HttpJson(
      HttpJsonSendAdaptor::new(client_provider, endpoint~, headers~),
    ),
  )
}

///|
pub fn OTLPExporterConfig::http_protobuf(
  client_provider : &ProtobufHttpClientProvider,
  endpoint? : String = "http://localhost:4318/v1/traces",
  headers? : Map[String, String] = {},
) -> OTLPExporterConfig {
  OTLPExporterConfig::default(
    ExportAdapter::HttpProtobuf(
      HttpProtobufSendAdaptor::new(client_provider, endpoint~, headers~),
    ),
  )
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
  let adaptor = self.export_adapter
  match adaptor {
    ExportAdapter::HttpJson(http_adaptor) => {
      let json_body = spans_to_resource_spans_json(spans)
      let client = http_adaptor.client_provider.get_json_client()
      self.export_spans_by_json_http_client(
        json_body, client, http_adaptor, spans,
      )
    }
    ExportAdapter::HttpProtobuf(http_adaptor) => {
      let protobuf_body = spans_to_resource_spans_protobuf_bytes(spans)
      let client = http_adaptor.client_provider.get_protobuf_client()
      self.export_spans_by_protobuf_http_client(
        protobuf_body, client, http_adaptor, spans,
      )
    }
    ExportAdapter::Stdout(stdout_adaptor) =>
      (stdout_adaptor.print)(spans_to_resource_spans_json(spans))
  }
}

///|
pub async fn OTLPExporter::export_spans_by_json_http_client(
  self : OTLPExporter,
  json_body : String,
  http_client : &JsonHttpClient,
  http_adaptor : HttpJsonSendAdaptor,
  spans : Array[Span],
) -> Unit {
  self.logger.log(
    "[OTLP] Starting export of " +
    spans.length().to_string() +
    " span(s) as JSON",
  )
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
            "[OTLP] Exported " + spans.length().to_string() + " span(s) as JSON",
          )
        } else {
          // HTTP error response - already handled by HttpStatusError
          self.logger.log(
            "[OTLP] Export failed with status " +
            response.status_code.to_string() +
            ": " +
            response.body,
          )
        }
      Err(error) => {
        // Classify and log error
        let error_type = match error {
          NetworkError(_) => "Network"
          RequestError(_) => "Request"
          HttpStatusError(_, _) => "HTTP Status"
          InvalidResponse(_) => "Invalid Response"
          TimeoutError(_) => "Timeout"
          SecurityError(_) => "Security"
        }
        self.logger.log(
          "[OTLP] " +
          error_type +
          " error: " +
          error.to_string() +
          (if error.is_retryable() { " (retryable)" } else { "" }),
        )
      }
    }
  } catch {
    err => self.logger.log("[OTLP] HTTP JSON export error: " + err.to_string())
  }
}

///|
pub async fn OTLPExporter::export_spans_by_protobuf_http_client(
  self : OTLPExporter,
  protobuf_body : Bytes,
  http_client : &ProtobufHttpClient,
  http_adaptor : HttpProtobufSendAdaptor,
  spans : Array[Span],
) -> Unit {
  self.logger.log(
    "[OTLP] Starting export of " +
    spans.length().to_string() +
    " span(s) as Protobuf",
  )
  try {
    let result = http_client.http_post_protobuf(
      http_adaptor.endpoint,
      protobuf_body,
      http_adaptor.headers.merge({ "Content-Type": "application/x-protobuf" }),
    )
    match result {
      Ok(response) =>
        if response.status_code >= 200 && response.status_code < 300 {
          // Success - span exported successfully
          self.logger.log(
            "[OTLP] Exported " +
            spans.length().to_string() +
            " span(s) as Protobuf",
          )
        } else {
          // HTTP error response - already handled by HttpStatusError
          self.logger.log(
            "[OTLP] Export failed with status " +
            response.status_code.to_string() +
            ": " +
            response.body,
          )
        }
      Err(error) => {
        // Classify and log error
        let error_type = match error {
          NetworkError(_) => "Network"
          RequestError(_) => "Request"
          HttpStatusError(_, _) => "HTTP Status"
          InvalidResponse(_) => "Invalid Response"
          TimeoutError(_) => "Timeout"
          SecurityError(_) => "Security"
        }
        self.logger.log(
          "[OTLP] " +
          error_type +
          " error: " +
          error.to_string() +
          (if error.is_retryable() { " (retryable)" } else { "" }),
        )
      }
    }
  } catch {
    err =>
      self.logger.log("[OTLP] HTTP Protobuf export error: " + err.to_string())
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
