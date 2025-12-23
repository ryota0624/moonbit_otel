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
