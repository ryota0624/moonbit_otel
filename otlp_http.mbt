// HTTP client abstraction for making OTLP export requests

///|
pub struct HttpRequest {
  url : String
  http_method : String
  headers : Map[String, String]
  body : String
} derive(ToJson, FromJson)

///|
pub struct HttpResponse {
  status_code : Int
  body : String
  error_code : Option[Int]
} derive(ToJson, FromJson)

///|
pub enum HttpError {
  NetworkError(String)
  // TimeoutError
  InvalidResponse(String)
} derive(Show)

// Default headers for OTLP JSON requests

///|
fn default_headers() -> Map[String, String] {
  let headers = Map::new()
  headers.set("Content-Type", "application/json")
  headers
}

// Make an HTTP POST request with JSON body
// This is a wrapper that will use FFI for WASM or native HTTP client for native targets

///|
pub async fn http_post_json(
  url : String,
  body : String,
  custom_headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  // Merge default headers with custom headers
  let headers = default_headers()
  custom_headers.each(fn(key, value) { headers.set(key, value) })

  // Build HTTP request
  let request = { url, http_method: "POST", headers, body }

  // Call native HTTP function (will be defined below based on target)
  http_post_internal(request)
}


// Helper to build request headers

///|
pub fn make_headers_map() -> Map[String, String] {
  Map::new()
}

///|
pub fn add_header(
  headers : Map[String, String],
  key : String,
  value : String,
) -> Map[String, String] {
  headers.set(key, value)
  headers
}
