///|
priv struct HttpClient {}

///|
pub fn json_http_client_provider() -> &JsonHttpClientProvider {
  HttpClient::{  }
}

///|
pub fn protobuf_http_client_provider() -> &ProtobufHttpClientProvider {
  HttpClient::{  }
}

// JSON HTTP Client実装

///|
impl JsonHttpClient for HttpClient with http_post_json(
  _ : HttpClient,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      // StringをUTF-8 Bytesに変換
      let utf8_bytes = @utf8.encode(body)
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
  })
}

///|
impl JsonHttpClientProvider for HttpClient with get_json_client(_ : HttpClient) -> &JsonHttpClient {
  HttpClient::{  }
}

// Protobuf HTTP Client実装

///|
impl ProtobufHttpClient for HttpClient with http_post_protobuf(
  _ : HttpClient,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      // Bytesを直接使用
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
  })
}

///|
impl ProtobufHttpClientProvider for HttpClient with get_protobuf_client(
  _ : HttpClient,
) -> &ProtobufHttpClient {
  HttpClient::{  }
}
