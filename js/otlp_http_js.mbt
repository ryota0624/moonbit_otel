///|
/// `suspend` will suspend the execution of the current coroutine.
/// The suspension will be handled by a callback passed to `suspend`
async fn[T, E : Error] suspend(
  // `f` is a callback for handling suspension
  f : (
    // the first parameter of `f` is used to resume the execution of the coroutine normally
    (T) -> Unit,
    // the second parameter of `f` is used to cancel the execution of the current coroutine
    // by throwing an error at suspension point
    (E) -> Unit,
  ) -> Unit,
) -> T raise E = "%async.suspend"

// FFI function for HTTP POST using JavaScript's fetch API
// Input: JSON string containing HttpRequest { url, http_method, headers, body }
// Output: JSON string containing HttpResponse { status_code, body }
//
// This function is imported from the JavaScript global scope (otel module)
// You must define this in your JavaScript runtime before using MoonBit

///|
priv struct JsonHttpClientOnFetchApi {}

///|
priv struct ProtobufHttpClientOnFetchApi {}

///|
pub fn json_http_client_provider() -> &@lib.JsonHttpClientProvider {
  JsonHttpClientOnFetchApi::{  }
}

///|
pub fn protobuf_http_client_provider() -> &@lib.ProtobufHttpClientProvider {
  ProtobufHttpClientOnFetchApi::{  }
}

///|
async fn http_post_internal(
  request : @lib.HttpRequest,
) -> Result[@lib.HttpResponse, @lib.HttpError] {
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
    let response : @lib.HttpResponse = @json.from_json(json)
    if response.status_code == 0 {
      // status_code 0 indicates a network or timeout error
      return Err(@lib.HttpError::network(response.body))
    } else if response.status_code >= 400 {
      // HTTP error responses
      return Err(
        @lib.HttpError::http_status(response.status_code, response.body),
      )
    }
    Ok(response)
  } catch {
    _err =>
      Err(@lib.HttpError::invalid_response("Failed to parse HTTP response"))
  }
}

///|
impl @lib.JsonHttpClient for JsonHttpClientOnFetchApi with http_post_json(
  _ : JsonHttpClientOnFetchApi,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[@lib.HttpResponse, @lib.HttpError] {
  http_post_internal({ url, http_method: "POST", headers, body })
}

///|
impl @lib.JsonHttpClientProvider for JsonHttpClientOnFetchApi with get_json_client(
  _ : JsonHttpClientOnFetchApi,
) -> &@lib.JsonHttpClient {
  JsonHttpClientOnFetchApi::{  }
}

///|
impl @lib.ProtobufHttpClient for ProtobufHttpClientOnFetchApi with http_post_protobuf(
  _ : ProtobufHttpClientOnFetchApi,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[@lib.HttpResponse, @lib.HttpError] {
  // Convert Bytes to String for the HTTP request
  http_post_internal({
    url,
    http_method: "POST",
    headers,
    body: body.to_string(),
  })
}

///|
impl @lib.ProtobufHttpClientProvider for ProtobufHttpClientOnFetchApi with get_protobuf_client(
  _ : ProtobufHttpClientOnFetchApi,
) -> &@lib.ProtobufHttpClient {
  ProtobufHttpClientOnFetchApi::{  }
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
  #|     console.log("requset body", body, headers);
  #|     // Set timeout for the fetch request
  #|     const controller = new AbortController();
  #|     const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  #|     // Make the fetch request and return promise that resolves to JSON string
  #|     return fetch(url, {
  #|       method: http_method || "POST",
  #|       headers: headers,
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
