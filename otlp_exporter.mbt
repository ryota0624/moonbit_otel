// OTLP (OpenTelemetry Protocol) Exporter
// Sends spans to an OpenTelemetry Collector via HTTP+JSON

///|
pub trait HttpClientFactory {
  async create_client(Self) -> &HttpClient
}

///|
pub struct OTLPExporterConfig {
  endpoint : String
  headers : Map[String, String]
  timeout_ms : Int
  http_client_factory : &HttpClientFactory
}

///|
pub struct OTLPExporter {
  config : OTLPExporterConfig
  priv mut http_client : &HttpClient?
}

///|
pub trait HttpClient {
  async http_post_json(
    Self,
    url : String,
    body : String,
    headers : Map[String, String],
  ) -> Result[HttpResponse, HttpError]
}

// Create default OTLP exporter configuration

///|
pub fn OTLPExporterConfig::default() -> OTLPExporterConfig {
  {
    endpoint: "http://localhost:4318/v1/traces",
    headers: Map::new(),
    timeout_ms: 30000,
    http_client_factory: http_client_factory(),
  }
}

// Add a custom header to the configuration

///|
pub fn OTLPExporterConfig::with_header(
  self : OTLPExporterConfig,
  key : String,
  value : String,
) -> OTLPExporterConfig {
  let new_headers = self.headers.copy()
  new_headers.set(key, value)
  { ..self, endpoint: self.endpoint }
}

// Set the endpoint URL

///|
pub fn OTLPExporterConfig::with_endpoint(
  self : OTLPExporterConfig,
  endpoint : String,
) -> OTLPExporterConfig {
  { ..self, endpoint, }
}

// Set the timeout in milliseconds

///|
pub fn OTLPExporterConfig::with_timeout(
  self : OTLPExporterConfig,
  timeout_ms : Int,
) -> OTLPExporterConfig {
  { ..self, timeout_ms, }
}

// Create a new OTLP exporter with the given configuration

///|
pub fn OTLPExporter::new(config : OTLPExporterConfig) -> OTLPExporter {
  { config, http_client: None }
}

// Create an OTLP exporter with default configuration

///|
pub fn OTLPExporter::with_default_config() -> OTLPExporter {
  OTLPExporter::new(OTLPExporterConfig::default())
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

  // Prepare HTTP headers
  let headers = self.config.headers.copy()
  headers.set("Content-Type", "application/json")
  if self.http_client is None {
    self.http_client = Some(self.config.http_client_factory.create_client())
  }

  // Send HTTP POST request
  match
    self.config.http_client_factory
    .create_client()
    .http_post_json(self.config.endpoint, json_body, headers) {
    Ok(response) =>
      if response.status_code >= 200 && response.status_code < 300 {
        // Success - span exported successfully
        println("[OTLP] Exported " + spans.length().to_string() + " span(s)")
      } else {
        // HTTP error response
        println(
          "[OTLP] Export failed with status " +
          response.status_code.to_string() +
          ": " +
          response.body,
        )
      }
    Err(error) =>
      // Network or transport error
      println("[OTLP] Export error: " + error.to_string())
  }
}

// Explicit implementation of SpanExporter trait for OTLPExporter

///|
pub fn OTLPExporter::shutdown(_ : OTLPExporter) -> Unit {
  println("[OTLP] OTLPExporter shutdown")
}

///|
pub impl SpanExporter for OTLPExporter with export_spans(
  self : OTLPExporter,
  spans : Array[Span],
) -> Unit {
  self.export_spans(spans)
}

///|
pub impl SpanExporter for OTLPExporter with shutdown(self : OTLPExporter) -> Unit {
  self.shutdown()
}
