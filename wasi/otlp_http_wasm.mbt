///|
struct HttpClientOnWasiHttp {}

///|
pub fn http_client_factory() -> &@otel.HttpClientFactory {
  HttpClientOnWasiHttp::{  }
}

///|
impl @otel.HttpClient for HttpClientOnWasiHttp with http_post_json(
  _ : HttpClientOnWasiHttp,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[@otel.HttpResponse, @otel.HttpError] {
  let stdout = @stdout.get_stdout()
  let field = @types.Fields::fields()
  for header in headers {
    let key = header.0
    let value = header.1
    guard field.append(key, @encoding/utf8.encode(value).to_fixedarray())
      is Ok(_) else {
      return Err(
        @otel.HttpError::NetworkError(
          "Failed to set request header \{key}: \{value}",
        ),
      )
    }
  }
  let req = @types.OutgoingRequest::outgoing_request(field)
  let _ = req.set_scheme(
    if url.has_prefix("https://") {
      Some(@types.Scheme::Https)
    } else {
      Some(@types.Scheme::Http)
    },
  )
  let authority = url
    .replace(old="https://", new="")
    .replace(old="http://", new="")
    .split("/")
    .to_array()[0]
  let _ = req.set_authority(Some(authority.to_string()))
  let _ = req.set_path_with_query(
    Some(
      url
      .replace(old="https://", new="")
      .replace(old="http://", new="")
      .replace(old=authority, new=""),
    ),
  )
  let _ = req.set_method(@types.Method::Post)
  let _ = stdout.write(
    @encoding/utf8.encode("Sending HTTP POST to \{url}\n").to_fixedarray(),
  )
  let _ = match req.body() {
    Ok(b) => {
      let stream = b.write()
      guard stream is Ok(write) else {
        return Err(
          @otel.HttpError::NetworkError("Failed to get request body stream"),
        )
      }
      let body_bytes = @encoding/utf8.encode(body)
      guard write.write(body_bytes.to_fixedarray()) is Ok(_) else {
        return Err(
          @otel.HttpError::NetworkError("Failed to write request body"),
        )
      }
      guard write.flush() is Ok(_) else {
        return Err(
          @otel.HttpError::NetworkError("Failed to flush request body"),
        )
      }
      let sub = write.subscribe()
      sub.block()
      guard b.finish(Some(field)) is Ok(_) else {
        return Err(
          @otel.HttpError::NetworkError("Failed to finish request body"),
        )
      }
      Ok(())
    }
    Err(_) =>
      return Err(@otel.HttpError::NetworkError("Failed to set request body"))
  }
  let result = @outgoingHandler.handle(req, None)
  match result {
    Ok(response) => {
      let sub = response.subscribe()
      sub.block()
      let res = response.get()
      if res is None {
        return Err(
          @otel.HttpError::InvalidResponse("No response received".to_string()),
        )
      }
      match res {
        None =>
          return Err(
            @otel.HttpError::InvalidResponse("Empty response".to_string()),
          )
        Some(resp) =>
          match resp {
            Ok(http_response) =>
              match http_response {
                Ok(http_res) => {
                  guard http_res.consume() is Ok(body) else {
                    return Err(
                      @otel.HttpError::InvalidResponse(
                        "Failed to consume HTTP response".to_string(),
                      ),
                    )
                  }
                  let body_stream = body.stream()
                  guard body_stream is Ok(data) else {
                    return Err(
                      @otel.HttpError::InvalidResponse(
                        "No body data received".to_string(),
                      ),
                    )
                  }
                  data.subscribe().block()
                  let response_content = read_all(data)
                  guard response_content is Ok(content) else {
                    return Err(
                      @otel.HttpError::InvalidResponse(
                        "Failed to read response content".to_string(),
                      ),
                    )
                  }
                  return Ok(@otel.HttpResponse::{
                    status_code: http_res.status().to_double().to_int(),
                    body: content,
                    error_code: None,
                  })
                }
                Err(err) =>
                  return Err(
                    @otel.HttpError::InvalidResponse(
                      "No HTTP response received \{err}",
                    ),
                  )
              }
            Err(_) => return Err(@otel.HttpError::NetworkError("Result::Err"))
          }
      }
    }
    Err(err) => return Err(@otel.HttpError::NetworkError(err.to_string()))
  }
}

///|
impl @otel.HttpClientFactory for HttpClientOnWasiHttp with create_client(
  _ : HttpClientOnWasiHttp,
) -> &@otel.HttpClient {
  HttpClientOnWasiHttp::{  }
}

///|
fn read_all(stream : @streams.InputStream) -> Result[String, @otel.HttpError] {
  let mut bytes = Bytes::new(0)
  let out = stream.read(1024)
  for {
    guard out is Ok(data) else {
      return @otel.HttpError::InvalidResponse(
          "Failed to read response body".to_string(),
        )
        |> Err(_)
    }
    bytes = bytes.add(Bytes::from_iter(data.iter()))
    if data.length() < 1024 {
      let decode_result = try? @encoding/utf8.decode(bytes)
      match decode_result {
        Ok(s) => return Ok(s)
        Err(_) =>
          return Err(
            @otel.HttpError::InvalidResponse(
              "Failed to decode response body".to_string(),
            ),
          )
      }
    }
  }
}
