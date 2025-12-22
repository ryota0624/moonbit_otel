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
  let response_json_str = http_post_impl(request.url, request.body, headers_json)

  // Parse response: String -> Json -> HttpResponse
  try {
    let json = @json.parse(response_json_str)
    let response : HttpResponse = @json.from_json(json)
    Ok(response)
  } catch {
    _err => Err(HttpError::InvalidResponse("Failed to parse HTTP response"))
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
