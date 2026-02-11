///|
priv struct JsonHttpClientOnFetchApi {}

///|
priv struct ProtobufHttpClientOnFetchApi {}

///|
pub fn json_http_client_provider() -> &JsonHttpClientProvider {
  JsonHttpClientOnFetchApi::{  }
}

///|
pub fn protobuf_http_client_provider() -> &ProtobufHttpClientProvider {
  ProtobufHttpClientOnFetchApi::{  }
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
  let response_json_str = suspend((resolve, _) => {
    http_post_impl(request_json, 500, responseStr => resolve(responseStr))
  })

  // Parse response: String -> Json -> HttpResponse
  try {
    let json = @json.parse(response_json_str)
    let response : HttpResponse = @json.from_json(json)
    if response.status_code == 0 {
      // status_code 0 indicates a network or timeout error
      return Err(HttpError::network(response.body))
    } else if response.status_code >= 400 {
      // HTTP error responses
      return Err(HttpError::http_status(response.status_code, response.body))
    }
    Ok(response)
  } catch {
    _err => Err(HttpError::invalid_response("Failed to parse HTTP response"))
  }
}

///|
impl JsonHttpClient for JsonHttpClientOnFetchApi with http_post_json(
  _ : JsonHttpClientOnFetchApi,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  http_post_internal({ url, http_method: "POST", headers, body })
}

///|
impl JsonHttpClientProvider for JsonHttpClientOnFetchApi with get_json_client(
  _ : JsonHttpClientOnFetchApi,
) -> &JsonHttpClient {
  JsonHttpClientOnFetchApi::{  }
}

///|
impl ProtobufHttpClient for ProtobufHttpClientOnFetchApi with http_post_protobuf(
  _ : ProtobufHttpClientOnFetchApi,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  // Send binary data directly for Protobuf
  http_post_protobuf_internal(url, body, headers)
}

///|
async fn http_post_protobuf_internal(
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  // Convert headers Map to JSON string for easier passing to JavaScript
  let headers_json = headers.to_json().stringify()

  // Call the native HTTP function via FFI with binary body
  let response_json_str = suspend((resolve, _) => {
    http_post_protobuf_impl(url, body, headers_json, 500, responseStr => {
      resolve(responseStr)
    })
  })

  // Parse response: String -> Json -> HttpResponse
  try {
    let json = @json.parse(response_json_str)
    let response : HttpResponse = @json.from_json(json)
    if response.status_code == 0 {
      // status_code 0 indicates a network or timeout error
      return Err(HttpError::network(response.body))
    } else if response.status_code >= 400 {
      // HTTP error responses
      return Err(HttpError::http_status(response.status_code, response.body))
    }
    Ok(response)
  } catch {
    _err => Err(HttpError::invalid_response("Failed to parse HTTP response"))
  }
}

///|
impl ProtobufHttpClientProvider for ProtobufHttpClientOnFetchApi with get_protobuf_client(
  _ : ProtobufHttpClientOnFetchApi,
) -> &ProtobufHttpClient {
  ProtobufHttpClientOnFetchApi::{  }
}

///|
extern "js" fn http_post_protobuf_impl(
  url : String,
  body : Bytes,
  headers_json : String,
  timeout_ms : Int,
  resolve : (String) -> Unit,
) -> Unit =
  #| (url, bodyBytes, headersJson, timeoutMs, resolve) => {
  #|   try {
  #|     // MoonBit Bytes is already a Uint8Array, use it directly
  #|     const bodyArray = bodyBytes;
  #|
  #|     // Parse headers from JSON
  #|     const headers = JSON.parse(headersJson);
  #|
  #|     // Set timeout for the fetch request
  #|     const controller = new AbortController();
  #|     const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  #|
  #|     // Make the fetch request with binary body
  #|     return fetch(url, {
  #|       method: "POST",
  #|       headers: headers,
  #|       body: bodyArray,
  #|       signal: controller.signal,
  #|     })
  #|       .then(response => {
  #|         clearTimeout(timeoutId);
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
  #|     const errorResponse = {
  #|       status_code: 0,
  #|       body: error.message,
  #|     };
  #|     return resolve(JSON.stringify(errorResponse));
  #|   }
  #| }

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
