// FFI function for HTTP POST using JavaScript's fetch API
// Input: JSON string containing HttpRequest { url, http_method, headers, body }
// Output: JSON string containing HttpResponse { status_code, body }
//
// This function is imported from the JavaScript global scope (otel module)
// You must define this in your JavaScript runtime before using MoonBit

///|
priv struct HttpClientOnFetchApi {}

///|
pub fn http_client_factory() -> &HttpClientFactory {
  HttpClientOnFetchApi::{  }
}

///|
async fn http_post_internal(
  request : HttpRequest,
) -> Result[HttpResponse, HttpError] {
  // Serialize entire request to JSON
  let request_json = request.to_json().stringify()
  // Call the native HTTP function via FFI
  // The actual implementation will be provided by the JavaScript/Node.js runtime
  // See http_ffi.js for the JavaScript implementation
  let response_json_str = suspend((resolve, _) => http_post_impl(
    request_json,
    500,
    responseStr => resolve(responseStr),
  ))

  // Parse response: String -> Json -> HttpResponse
  try {
    let json = @json.parse(response_json_str)
    let response : HttpResponse = @json.from_json(json)
    if response.status_code == 0 {
      /// TODO: Differentiate timeout vs network errors
      return Err(HttpError::NetworkError(response.body))
    }
    Ok(response)
  } catch {
    _err => Err(HttpError::InvalidResponse("Failed to parse HTTP response"))
  }
}

///|
impl HttpClient for HttpClientOnFetchApi with http_post_json(
  _ : HttpClientOnFetchApi,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  http_post_internal({
    url,
    http_method: "POST",
    headers: default_headers().merge(headers),
    body,
  })
}

///|
impl HttpClientFactory for HttpClientOnFetchApi with create_client(
  _ : HttpClientOnFetchApi,
) -> &HttpClient {
  HttpClientOnFetchApi::{  }
}

///|
extern "js" fn http_post_impl(
  request_json : String,
  timeout_ms : Int,
  resolve : (String) -> Unit,
) -> Unit =
  #| (requestJson, timeoutMs, resolve) => {
  #|   try {
  #|     // Parse the request from MoonBit
  #|     const request = JSON.parse(requestJson);
  #|     const { url, http_method, headers, body } = request;
  #|     console.log("requset body", body);
  #|     // Set timeout for the fetch request
  #|     const controller = new AbortController();
  #|     const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  #|     // Make the fetch request and return promise that resolves to JSON string
  #|     return fetch(url, {
  #|       method: http_method || "POST",
  #|       headers: headers || { "Content-Type": "application/json" },
  #|       body: body,
  #|       signal: controller.signal,
  #|     })
  #|       .then(response => {
  #|         clearTimeout(timeoutId);
  #|         // Read the response body
  #|         return response.text().then(responseBody => {
  #|           const result = {
  #|             status_code: response.status,
  #|             body: responseBody,
  #|           };
  #|           return JSON.stringify(result);
  #|         });
  #|       })
  #|       .then(resolve)
  #|       .catch(error => {
  #|         clearTimeout(timeoutId);
  #|         // Handle different error types
  #|         let errorBody = "Unknown error";
  #|         if (error.message !== undefined) {
  #|           errorBody = error.message;
  #|         }
  #|         const errorResponse = {
  #|           status_code: 0,
  #|           body: errorBody,
  #|           error_code: error.cause ?? error.cause.errno,
  #|         };
  #|         resolve(JSON.stringify(errorResponse));
  #|       });
  #|   } catch (error) {
  #|     // Handle JSON parsing errors
  #|     const errorResponse = {
  #|       status_code: 0,
  #|       body: error.message,
  #|     };
  #|     return resolve(errorResponse);
  #|   }
  #| }
