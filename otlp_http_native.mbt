///|
priv struct JsonHttpClientOnAsyncHttp {}

///|
priv struct ProtobufHttpClientOnAsyncHttp {}

///|
pub fn json_http_client_provider() -> &JsonHttpClientProvider {
  JsonHttpClientOnAsyncHttp::{  }
}

///|
pub fn protobuf_http_client_provider() -> &ProtobufHttpClientProvider {
  ProtobufHttpClientOnAsyncHttp::{  }
}

///|
impl JsonHttpClient for JsonHttpClientOnAsyncHttp with http_post_json(
  _ : JsonHttpClientOnAsyncHttp,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      // Convert String to UTF-8 bytes for HTTP request
      let utf8_bytes = @encoding/utf8.encode(body)
      let (response, data) = @http.post(url, utf8_bytes, headers~)
      if response.code >= 200 && response.code < 300 {
        Ok(HttpResponse::{
          status_code: response.code,
          body: data.text(),
          error_code: None,
        })
      } else {
        Err(HttpError::http_status(response.code, data.text()))
      }
    } catch {
      err => Err(HttpError::network(err.to_string()))
    }
  }) // 5 seconds timeout
}

///|
impl JsonHttpClientProvider for JsonHttpClientOnAsyncHttp with get_json_client(
  _ : JsonHttpClientOnAsyncHttp,
) -> &JsonHttpClient {
  JsonHttpClientOnAsyncHttp::{  }
}

///|
impl ProtobufHttpClient for ProtobufHttpClientOnAsyncHttp with http_post_protobuf(
  _ : ProtobufHttpClientOnAsyncHttp,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      let (response, data) = @http.post(url, body, headers~)
      if response.code >= 200 && response.code < 300 {
        Ok(HttpResponse::{
          status_code: response.code,
          body: data.text(),
          error_code: None,
        })
      } else {
        Err(HttpError::http_status(response.code, data.text()))
      }
    } catch {
      err => Err(HttpError::network(err.to_string()))
    }
  }) // 5 seconds timeout
}

///|
impl ProtobufHttpClientProvider for ProtobufHttpClientOnAsyncHttp with get_protobuf_client(
  _ : ProtobufHttpClientOnAsyncHttp,
) -> &ProtobufHttpClient {
  ProtobufHttpClientOnAsyncHttp::{  }
}
