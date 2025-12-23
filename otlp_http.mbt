// HTTP client abstraction for making OTLP export requests

///|
pub(all) struct HttpRequest {
  url : String
  http_method : String
  headers : Map[String, String]
  body : String
} derive(ToJson, FromJson)

///|
pub(all) struct HttpResponse {
  status_code : Int
  body : String
  error_code : Int?
} derive(ToJson, FromJson)

///|
pub(all) enum HttpError {
  NetworkError(String)
  // TimeoutError
  InvalidResponse(String)
} derive(Show)

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
