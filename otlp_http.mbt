// HTTP client abstraction for making OTLP export requests

pub struct HttpRequest {
  url : String
  http_method : String
  headers : Map[String, String]
  body : String
} derive(ToJson, FromJson)

pub struct HttpResponse {
  status_code : Int
  body : String
} derive(ToJson, FromJson)

pub enum HttpError {
  NetworkError(String)
  TimeoutError
  InvalidResponse(String)
} derive(Show)

// Default headers for OTLP JSON requests
fn default_headers() -> Map[String, String] {
  let headers = Map::new()
  headers.set("Content-Type", "application/json")
  headers
}

// Make an HTTP POST request with JSON body
// This is a wrapper that will use FFI for WASM or native HTTP client for native targets
pub fn http_post_json(
  url : String,
  body : String,
  custom_headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  // Merge default headers with custom headers
  let headers = default_headers()
  custom_headers.each(fn(key, value) { headers.set(key, value) })

  // Build HTTP request
  let request = {
    url,
    http_method: "POST",
    headers,
    body,
  }

  // Call native HTTP function (will be defined below based on target)
  http_post_internal(request)
}

fn http_post_internal(
  request : HttpRequest,
) -> Result[HttpResponse, HttpError] {
  // Serialize request headers to JSON
  let headers_json = request.headers.to_json().to_string()

  // Call the native HTTP function via FFI
  // The actual implementation will be provided by the JavaScript/Node.js runtime
  // See http_ffi.js for the JavaScript implementation
  let response_json = http_post_impl(request.url, request.body, headers_json)

  // Parse the response JSON using FromJson
  match response_json.from_json() {
    Ok(response) => Ok(response)
    Err(_) => Err(HttpError::InvalidResponse("Failed to parse HTTP response"))
  }
}

// FFI stub for HTTP POST - will be implemented via JavaScript/Node.js
// This function needs to be bound at runtime to call the fetch API
fn http_post_impl(
  url : String,
  body : String,
  headers : String,
) -> String {
  // Placeholder - will be replaced with actual FFI implementation
  // In a real scenario, this would call JavaScript's fetch API via FFI
  ignore(url)
  ignore(body)
  ignore(headers)
  "{\"error\": \"HTTP implementation requires FFI binding\"}"
}

// Convert headers map to JSON string for FFI
fn headers_to_json(headers : Map[String, String]) -> String {
  let mut json = "{"
  let mut first = true

  headers.each(fn(key, value) {
    if not(first) {
      json = json + ","
    }
    json = json + "\"" + escape_json_string(key) + "\":\"" + escape_json_string(value) + "\""
    first = false
  })

  json = json + "}"
  json
}

// Parse HTTP response JSON from FFI
fn parse_http_response(response_json : String) -> Result[HttpResponse, HttpError] {
  // Expected format: {"status_code": 200, "body": "..."}
  // For simplicity, we'll do basic parsing
  // A production system would use a proper JSON parser

  if response_json.contains("\"error\"") {
    // Extract error message
    match extract_error_message(response_json) {
      Some(error_msg) => {
        if error_msg.contains("timeout") || error_msg.contains("Timeout") {
          Err(HttpError::TimeoutError)
        } else {
          Err(HttpError::NetworkError(error_msg))
        }
      }
      None => Err(HttpError::NetworkError("Unknown error from HTTP request"))
    }
  } else {
    // Extract status code and body
    match (extract_status_code(response_json), extract_response_body(response_json)) {
      (Some(status_code), Some(body)) => {
        Ok({ status_code, body })
      }
      _ => Err(HttpError::InvalidResponse("Failed to parse HTTP response"))
    }
  }
}

// Simple helper to parse integer from string
fn simple_parse_int(s : String) -> Option[Int] {
  if s.length() == 0 {
    return None
  }
  let mut result = 0
  let mut is_negative = false
  let mut start_idx = 0

  // Check for negative sign
  if s[0] == '-' {
    is_negative = true
    start_idx = 1
  }

  for i in start_idx..<s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }

  if is_negative {
    Some(-result)
  } else {
    Some(result)
  }
}

// Extract status code from response JSON
fn extract_status_code(json : String) -> Option[Int] {
  match json.find("\"status_code\":") {
    Some(idx) => {
      let prefix_len = "\"status_code\":".length()
      let start = idx + prefix_len
      let mut end = start
      let json_len = json.length()
      while end < json_len {
        let c = json[end]
        if c == ',' || c == '}' {
          break
        }
        end = end + 1
      }
      // Extract substring and convert to int
      let mut num_str = ""
      for i in start..<end {
        num_str = num_str + json[i].to_string()
      }
      let trimmed_str = num_str.trim().to_string()
      // Simple integer parsing
      match simple_parse_int(trimmed_str) {
        Some(n) => Some(n)
        None => None
      }
    }
    None => None
  }
}

// Extract response body from response JSON
fn extract_response_body(json : String) -> Option[String] {
  match json.find("\"body\":\"") {
    Some(idx) => {
      let prefix_len = "\"body\":\"".length()
      let start = idx + prefix_len
      let mut end = start
      let json_len = json.length()
      while end < json_len {
        if json[end] == '"' {
          break
        }
        end = end + 1
      }
      // Extract substring
      let mut body = ""
      for i in start..<end {
        body = body + json[i].to_string()
      }
      Some(body)
    }
    None => None
  }
}

// Extract error message from error JSON
fn extract_error_message(json : String) -> Option[String] {
  match json.find("\"error\":\"") {
    Some(idx) => {
      let prefix_len = "\"error\":\"".length()
      let start = idx + prefix_len
      let mut end = start
      let json_len = json.length()
      while end < json_len {
        if json[end] == '"' {
          break
        }
        end = end + 1
      }
      // Extract substring
      let mut error_msg = ""
      for i in start..<end {
        error_msg = error_msg + json[i].to_string()
      }
      Some(error_msg)
    }
    None => None
  }
}

// Helper to build request headers
pub fn make_headers_map() -> Map[String, String] {
  Map::new()
}

pub fn add_header(
  headers : Map[String, String],
  key : String,
  value : String,
) -> Map[String, String] {
  headers.set(key, value)
  headers
}
