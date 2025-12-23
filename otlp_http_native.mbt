///|
struct HttpClientOnAsyncHttp {}

///|
fn http_client_factory() -> &HttpClientFactory {
  HttpClientOnAsyncHttp::{  }
}

///|
impl HttpClient for HttpClientOnAsyncHttp with http_post_json(
  _ : HttpClientOnAsyncHttp,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[HttpResponse, HttpError] {
  @async.with_timeout(5000, async fn() {
    try {
      let (response, data) = @http.post(url, body, headers~)
      if response.code >= 200 && response.code < 300 {
        Ok({ status_code: response.code, body: data.text(), error_code: None })
      } else {
        Err(HttpError::InvalidResponse(data.text()))
      }
    } catch {
      err => Err(HttpError::NetworkError(err.to_string()))
    }
  }) // 5 seconds timeout
}

///|
impl HttpClientFactory for HttpClientOnAsyncHttp with create_client(
  _ : HttpClientOnAsyncHttp,
) -> &HttpClient {
  HttpClientOnAsyncHttp::{  }
}
