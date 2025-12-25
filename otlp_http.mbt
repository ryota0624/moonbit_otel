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
  // Network-level errors (DNS, connection, etc.)
  NetworkError(String)
  // HTTP request construction errors (invalid URL, headers, etc.)
  RequestError(String)
  // HTTP response errors with status code
  HttpStatusError(Int, String) // (status_code, body)
  // Response parsing/reading errors
  InvalidResponse(String)
  // Timeout errors
  TimeoutError(String)
  // SSL/TLS errors
  SecurityError(String)
} derive(Show)

///|
// Helper functions for error classification
pub fn HttpError::network(message : String) -> HttpError {
  NetworkError(message)
}

///|
pub fn HttpError::request(message : String) -> HttpError {
  RequestError(message)
}

///|
pub fn HttpError::http_status(status_code : Int, body : String) -> HttpError {
  HttpStatusError(status_code, body)
}

///|
pub fn HttpError::invalid_response(message : String) -> HttpError {
  InvalidResponse(message)
}

///|
pub fn HttpError::timeout(message : String) -> HttpError {
  TimeoutError(message)
}

///|
pub fn HttpError::security(message : String) -> HttpError {
  SecurityError(message)
}

///|
// Check if the error is retryable
pub fn HttpError::is_retryable(self : HttpError) -> Bool {
  match self {
    NetworkError(_) | TimeoutError(_) => true
    HttpStatusError(status, _) => status >= 500 // Server errors are retryable
    _ => false
  }
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
