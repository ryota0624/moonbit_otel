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
  // Serialize entire request to JSON
  let request_json = request.to_json().to_string()

  // Call the native HTTP function via FFI
  // The actual implementation will be provided by the JavaScript/Node.js runtime
  // See http_ffi.js for the JavaScript implementation
  let response_json_str = http_post_impl(request_json)

  // Parse response: String -> Json -> HttpResponse
  try {
    let json = @json.parse(response_json_str)
    let response : HttpResponse = @json.from_json(json)
    Ok(response)
  } catch {
    _err => Err(HttpError::InvalidResponse("Failed to parse HTTP response"))
  }
}

// FFI function for HTTP POST using JavaScript's fetch API
// Input: JSON string containing HttpRequest { url, http_method, headers, body }
// Output: JSON string containing HttpResponse { status_code, body }
//
// This function is imported from the JavaScript global scope (otel module)
// You must define this in your JavaScript runtime before using MoonBit
extern "js" fn http_post_impl(request_json : String) -> String = 
#| function httpPost(requestJson) {
#|   try {
#|     // Parse the request from MoonBit
#|     const request = JSON.parse(requestJson);
#|     const { url, http_method, headers, body } = request;#| 
#|     // Set timeout for the fetch request (30 seconds by default)
#|     const controller = new AbortController();
#|     const timeoutId = setTimeout(() => controller.abort(), 30000);#| 
#|     // Make the fetch request and return promise that resolves to JSON string
#|     return fetch(url, {
#|       method: http_method || "POST",
#|       headers: headers || { "Content-Type": "application/json" },
#|       body: body,
#|       signal: controller.signal,
#|     })
#|       .then(response => {
#|         clearTimeout(timeoutId);#| 
#|         // Read the response body
#|         return response.text().then(responseBody => {
#|           const result = {
#|             status_code: response.status,
#|             body: responseBody,
#|           };
#|           return JSON.stringify(result);
#|         });
#|       })
#|       .catch(error => {
#|         clearTimeout(timeoutId);#| 
#|         // Handle different error types
#|         let errorBody = "Unknown error";
#|         if (error.name === "AbortError") {
#|           errorBody = "Request timeout";
#|         } else if (error instanceof TypeError) {
#|           errorBody = `Network error: ${error.message}`;
#|         } else {
#|           errorBody = `Error: ${error.message}`;
#|         }#|
#|         const errorResponse = {
#|           status_code: 0,
#|           body: errorBody,
#|         };#| 
#|         return JSON.stringify(errorResponse);
#|       });
#|   } catch (error) {
#|     // Handle JSON parsing errors
#|     const errorResponse = {
#|       status_code: 0,
#|       body: `Invalid request format: ${error.message}`,
#|     };
#|     return JSON.stringify(errorResponse);
#|   }
#| }

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
