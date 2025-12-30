///|
priv struct JsonHttpClientOnAsyncHttp {}

///|
priv struct ProtobufHttpClientOnAsyncHttp {}

///|
pub fn json_http_client_provider() -> &@lib.JsonHttpClientProvider {
  JsonHttpClientOnAsyncHttp::{  }
}

///|
pub fn protobuf_http_client_provider() -> &@lib.ProtobufHttpClientProvider {
  ProtobufHttpClientOnAsyncHttp::{  }
}

///|
impl @lib.JsonHttpClient for JsonHttpClientOnAsyncHttp with http_post_json(
  _ : JsonHttpClientOnAsyncHttp,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[@lib.HttpResponse, @lib.HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      let (response, data) = @http.post(url, body.to_bytes(), headers~)
      if response.code >= 200 && response.code < 300 {
        Ok(@lib.HttpResponse::{
          status_code: response.code,
          body: data.text(),
          error_code: None,
        })
      } else {
        Err(@lib.HttpError::http_status(response.code, data.text()))
      }
    } catch {
      err => Err(@lib.HttpError::network(err.to_string()))
    }
  }) // 5 seconds timeout
}

///|
impl @lib.JsonHttpClientProvider for JsonHttpClientOnAsyncHttp with get_json_client(
  _ : JsonHttpClientOnAsyncHttp,
) -> &@lib.JsonHttpClient {
  JsonHttpClientOnAsyncHttp::{  }
}

///|
impl @lib.ProtobufHttpClient for ProtobufHttpClientOnAsyncHttp with http_post_protobuf(
  _ : ProtobufHttpClientOnAsyncHttp,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[@lib.HttpResponse, @lib.HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      let (response, data) = @http.post(url, body, headers~)
      if response.code >= 200 && response.code < 300 {
        Ok(@lib.HttpResponse::{
          status_code: response.code,
          body: data.text(),
          error_code: None,
        })
      } else {
        Err(@lib.HttpError::http_status(response.code, data.text()))
      }
    } catch {
      err => Err(@lib.HttpError::network(err.to_string()))
    }
  }) // 5 seconds timeout
}

///|
impl @lib.ProtobufHttpClientProvider for ProtobufHttpClientOnAsyncHttp with get_protobuf_client(
  _ : ProtobufHttpClientOnAsyncHttp,
) -> &@lib.ProtobufHttpClient {
  ProtobufHttpClientOnAsyncHttp::{  }
}
