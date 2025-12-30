///|
priv struct HttpClientOnAsyncHttp {}

///|
pub fn http_client_provider() -> &@lib.HttpClientProvider {
  HttpClientOnAsyncHttp::{  }
}

///|
impl @lib.HttpClient for HttpClientOnAsyncHttp with http_post_json(
  _ : HttpClientOnAsyncHttp,
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
impl @lib.HttpClientProvider for HttpClientOnAsyncHttp with get_client(
  _ : HttpClientOnAsyncHttp,
) -> &@lib.HttpClient {
  HttpClientOnAsyncHttp::{  }
}
