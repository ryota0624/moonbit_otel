// OTLP (OpenTelemetry Protocol) Exporter
// Sends spans to an OpenTelemetry Collector via HTTP+JSON

pub struct OTLPExporterConfig {
  endpoint : String
  headers : Map[String, String]
  timeout_ms : Int
}

pub struct OTLPExporter {
  config : OTLPExporterConfig
}

// Create default OTLP exporter configuration
pub fn OTLPExporterConfig::default() -> OTLPExporterConfig {
  {
    endpoint: "http://localhost:4318/v1/traces",
    headers: Map::new(),
    timeout_ms: 30000,
  }
}

// Add a custom header to the configuration
pub fn OTLPExporterConfig::with_header(
  self : OTLPExporterConfig,
  key : String,
  value : String,
) -> OTLPExporterConfig {
  let new_headers = self.headers.copy()
  new_headers.set(key, value)
  {
    endpoint: self.endpoint,
    headers: new_headers,
    timeout_ms: self.timeout_ms,
  }
}

// Set the endpoint URL
pub fn OTLPExporterConfig::with_endpoint(
  self : OTLPExporterConfig,
  endpoint : String,
) -> OTLPExporterConfig {
  {
    endpoint,
    headers: self.headers,
    timeout_ms: self.timeout_ms,
  }
}

// Set the timeout in milliseconds
pub fn OTLPExporterConfig::with_timeout(
  self : OTLPExporterConfig,
  timeout_ms : Int,
) -> OTLPExporterConfig {
  {
    endpoint: self.endpoint,
    headers: self.headers,
    timeout_ms,
  }
}

// Create a new OTLP exporter with the given configuration
pub fn OTLPExporter::new(config : OTLPExporterConfig) -> OTLPExporter {
  { config, }
}

// Create an OTLP exporter with default configuration
pub fn OTLPExporter::with_default_config() -> OTLPExporter {
  OTLPExporter::new(OTLPExporterConfig::default())
}

// Implementation of SpanExporter trait for OTLPExporter
pub fn OTLPExporter::export_spans(
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

  // Send HTTP POST request
  match http_post_json(self.config.endpoint, json_body, headers) {
    Ok(response) => {
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
    }
    Err(error) => {
      // Network or transport error
      println("[OTLP] Export error: " + error.to_string())
    }
  }
}

// Shutdown the exporter (cleanup resources)
pub fn OTLPExporter::shutdown(self : OTLPExporter) -> Unit {
  println("[OTLP] OTLPExporter shutdown")
}
