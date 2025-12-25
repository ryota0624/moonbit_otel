///|
priv struct HttpClientOnWasiHttp {}

///|
pub fn http_client_provider() -> &@otel.HttpClientProvider {
  HttpClientOnWasiHttp::{  }
}

///|
fn parseUrl(url : String) -> (@types.Scheme, String, String) {
  println(url)
  let exclude_schema = url
    .replace(old="https://", new="")
    .replace(old="http://", new="")
    .split("/")
    .to_array()
  let separator = "/"
  let path = if exclude_schema.length() > 1 {
    let joined = exclude_schema[1:].join(separator)
    "/\{joined}"
  } else {
    "/"
  }
  (
    if url.has_prefix("https://") {
      @types.Scheme::Https
    } else {
      @types.Scheme::Http
    },
    exclude_schema[0].to_string(),
    path,
  )
}

///|
impl @otel.HttpClient for HttpClientOnWasiHttp with http_post_json(
  _ : HttpClientOnWasiHttp,
  url : String,
  body : String,
  headers : Map[String, String],
) -> Result[@otel.HttpResponse, @otel.HttpError] {
  let field = @types.Fields::fields()
  for header in headers {
    let key = header.0
    let value = header.1
    guard field.append(key, @encoding/utf8.encode(value).to_fixedarray())
      is Ok(_) else {
      return Err(
        @otel.HttpError::request(
          "Failed to set request header \{key}: \{value}",
        ),
      )
    }
  }
  let (schema, authority, path) = parseUrl(url)
  let req = @types.OutgoingRequest::outgoing_request(field)
  guard req.set_scheme(schema |> Some(_)) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to set scheme"))
  }
  guard req.set_authority(Some(authority.to_string())) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to set authority"))
  }
  guard req.set_path_with_query(Some(path)) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to set path: \{path}"))
  }
  guard req.set_method(@types.Method::Post) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to set method"))
  }
  guard req.body() is Ok(b) else {
    return Err(@otel.HttpError::request("Failed to create request body"))
  }
  let stream = b.write()
  guard stream is Ok(write) else {
    return Err(@otel.HttpError::request("Failed to get request body stream"))
  }
  let body_bytes = @encoding/utf8.encode(body)
  guard write.write(body_bytes.to_fixedarray()) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to write request body"))
  }
  guard write.flush() is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to flush request body"))
  }
  write.drop()
  guard b.finish(None) is Ok(_) else {
    return Err(@otel.HttpError::request("Failed to finish request body"))
  }

  // Send the request using OutgoingHandler
  let result = @outgoingHandler.handle(req, None)
  guard result is Ok(response) else {
    return Err(
      @otel.HttpError::network("Failed to send HTTP request \{result}"),
    )
  }
  let response_sub = response.subscribe()
  response_sub.block()
  response_sub.drop()
  let res = response.get()
  guard res is Some(http_response) else {
    return Err(@otel.HttpError::timeout("No response received"))
  }
  guard http_response is Ok(http_response) else {
    return Err(@otel.HttpError::invalid_response("Failed to get HTTP response"))
  }
  guard http_response is Ok(http_res) else {
    return Err(@otel.HttpError::invalid_response("Failed to get HTTP response"))
  }
  defer http_res.drop()
  guard http_res.consume() is Ok(body) else {
    return Err(
      @otel.HttpError::invalid_response("Failed to consume HTTP response"),
    )
  }
  defer body.drop()
  let body_stream = body.stream()
  guard body_stream is Ok(data) else {
    return Err(@otel.HttpError::invalid_response("No body data received"))
  }
  let data_sub = data.subscribe()
  data_sub.block()
  data_sub.drop()
  let response_content = read_all(data)
  guard response_content is Ok(content) else {
    return Err(
      @otel.HttpError::invalid_response("Failed to read response content"),
    )
  }
  data.drop()
  return Ok(@otel.HttpResponse::{
    status_code: http_res.status().to_double().to_int(),
    body: content,
    error_code: None,
  })
}

///|
impl @otel.HttpClientProvider for HttpClientOnWasiHttp with get_client(
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
      return @otel.HttpError::invalid_response("Failed to read response body")
        |> Err(_)
    }
    bytes = bytes.add(Bytes::from_iter(data.iter()))
    if data.length() < 1024 {
      let decode_result = try? @encoding/utf8.decode(bytes)
      match decode_result {
        Ok(s) => return Ok(s)
        Err(_) =>
          return Err(
            @otel.HttpError::invalid_response("Failed to decode response body"),
          )
      }
    }
  }
}
