# HTTP POST FFI Implementation for Node.js

This document describes the implementation of `http_post_internal` for Node.js using Foreign Function Interface (FFI) to call the fetch API.

## Overview

The MoonBit OpenTelemetry library needs to make HTTP POST requests to send spans to the OTLP (OpenTelemetry Protocol) collector. Since MoonBit compiles to WebAssembly, we use FFI to bridge between MoonBit code and JavaScript/Node.js's native fetch API.

## Architecture

```
MoonBit Code (otlp_http.mbt)
    ↓
http_post_internal()
    ↓
http_post_impl() [FFI stub]
    ↓
JavaScript/Node.js fetch API
    ↓
HTTP Response
    ↓
Response parsing in MoonBit
    ↓
Result[HttpResponse, HttpError]
```

## File Structure

### 1. [otlp_http.mbt](otlp_http.mbt)

The main MoonBit implementation file containing:

#### Public Functions

- **`http_post_json(url, body, custom_headers)`** - High-level HTTP POST function
  - Merges custom headers with default headers (Content-Type: application/json)
  - Calls `http_post_internal` to perform the request

#### Internal Functions

- **`http_post_internal(request)`** - Core HTTP POST implementation
  - Converts headers map to JSON string format
  - Calls the FFI function `http_post_impl`
  - Parses the response JSON and returns `Result[HttpResponse, HttpError]`

- **`http_post_impl(url, body, headers)`** - FFI stub
  - Placeholder function that will be bound to JavaScript implementation at runtime
  - Currently returns an error message indicating FFI binding is required

- **`headers_to_json(headers)`** - Converts Map to JSON string
  - Iterates through header key-value pairs
  - Uses `escape_json_string` to properly escape special characters
  - Returns JSON object string like `{"key1":"value1","key2":"value2"}`

- **`parse_http_response(response_json)`** - Parses response from FFI
  - Checks for error fields in response JSON
  - Extracts status code and body on success
  - Distinguishes between timeout errors and network errors

#### Helper Functions

- **`extract_status_code(json)`** - Extracts HTTP status code from response JSON
- **`extract_response_body(json)`** - Extracts response body from response JSON
- **`extract_error_message(json)`** - Extracts error message from error response
- **`simple_parse_int(s)`** - Simple integer parser (MoonBit string API limitation)

### 2. [http_ffi.js](http_ffi.js)

JavaScript/Node.js implementation file containing:

- **`ffiHttpPost(url, body, headersJson)`** - Main FFI function
  - Parses headers JSON string
  - Sets default Content-Type header if not provided
  - Calls fetch API with 30-second timeout
  - Returns response as JSON string with format:
    - Success: `{"status_code": 200, "body": "..."}`
    - Error: `{"error": "error message"}`

## Data Structures

### HttpRequest
```moonbit
struct HttpRequest {
  url : String
  http_method : String
  headers : Map[String, String]
  body : String
}
```

### HttpResponse
```moonbit
struct HttpResponse {
  status_code : Int
  body : String
}
```

### HttpError
```moonbit
enum HttpError {
  NetworkError(String)
  TimeoutError
  InvalidResponse(String)
}
```

## Response Format

### Success Response (from JavaScript)
```json
{
  "status_code": 200,
  "body": "response body content"
}
```

### Error Response (from JavaScript)
```json
{
  "error": "error message"
}
```

## FFI Binding Setup

### How FFI Works in This Implementation

1. **MoonBit Side**: The `http_post_impl` function is declared as a stub that needs JavaScript implementation
2. **JavaScript Side**: The `http_ffi.js` file implements the actual fetch API call
3. **Runtime Binding**: When compiling to JavaScript target, the FFI function needs to be bound

### Setting Up FFI in Your Build System

#### Option 1: Using moon build with custom FFI

You need to configure your build system to:

1. Compile MoonBit to JavaScript target
2. Inject the `http_ffi.js` module as an FFI provider

Example moon.pkg.json configuration:
```json
{
  "is-main": true,
  "import": [
    {
      "path": "ryota0624/moonbit_otel",
      "alias": "lib"
    }
  ]
}
```

#### Option 2: Manual Integration

If building directly with Node.js:

```javascript
// Load the FFI module
const httpFfi = require('./http_ffi.js');

// Make the function globally available
globalThis.ffiHttpPost = httpFfi.ffiHttpPost;

// Load your compiled MoonBit module
const wasm = require('./your-compiled-module.js');
```

#### Option 3: Using a Bundler

With webpack/rollup:

```javascript
import { ffiHttpPost } from './http_ffi.js';

// Provide as external import
declare function ffiHttpPost(url: string, body: string, headers: string): string;
```

## Error Handling

The implementation handles several error cases:

1. **Network Errors**: Connection failures, DNS resolution failures
2. **Timeout Errors**: Requests exceeding 30-second timeout
3. **Invalid Response**: Response cannot be parsed as JSON
4. **HTTP Errors**: Server returns non-2xx status code (not treated as error, status is in response)

Example error handling:

```moonbit
match http_post_json(url, body, headers) {
  Ok(response) => {
    if response.status_code >= 200 && response.status_code < 300 {
      // Success - process response.body
    } else {
      // HTTP error - handle response.status_code
    }
  }
  Err(error) => {
    match error {
      HttpError::TimeoutError => println("Request timeout")
      HttpError::NetworkError(msg) => println("Network error: " + msg)
      HttpError::InvalidResponse(msg) => println("Invalid response: " + msg)
    }
  }
}
```

## Usage Example

```moonbit
fn send_spans_to_otlp(spans : Array[Span], endpoint : String) -> Unit {
  let json_body = spans_to_json(spans)
  let headers = Map::new()
  headers.set("Content-Type", "application/json")
  headers.set("Authorization", "Bearer token")

  match http_post_json(endpoint, json_body, headers) {
    Ok(response) => {
      if response.status_code >= 200 && response.status_code < 300 {
        println("Exported " + spans.length().to_string() + " spans")
      } else {
        println("Export failed: " + response.status_code.to_string())
      }
    }
    Err(error) => {
      println("Export error: " + error.to_string())
    }
  }
}
```

## String Parsing Implementation

Due to MoonBit's wasm-gc backend limitations, the implementation includes custom parsing:

1. **`simple_parse_int(s)`** - Manual integer parsing since `String.parse_int()` is not available in wasm-gc
2. **Character-by-character extraction** - JSON field extraction done manually without advanced string slicing

This approach trades some efficiency for compatibility with MoonBit's current FFI capabilities.

## Testing

To test the HTTP implementation:

```moonbit
test "http_post_json succeeds with valid request" {
  let headers = Map::new()
  let result = http_post_json(
    "http://localhost:4318/v1/traces",
    "{\"test\": true}",
    headers
  )

  match result {
    Ok(response) => {
      assert_eq!(response.status_code, 200)
    }
    Err(_) => panic("Expected successful HTTP request")
  }
}
```

## Future Improvements

1. **Proper JSON Parser**: Implement or integrate a JSON parser for more robust parsing
2. **Connection Pooling**: Reuse HTTP connections for better performance
3. **Retry Logic**: Automatic retry with exponential backoff for transient failures
4. **Metrics**: Track HTTP request metrics (latency, success rate)
5. **Async/Await Support**: If MoonBit adds async support, use native async/await instead of FFI

## Compatibility

- **MoonBit Target**: wasm-gc backend
- **JavaScript Runtime**: Node.js 16+ (for fetch API support)
- **Browser Support**: Modern browsers with fetch API support

## References

- [MoonBit FFI Documentation](https://www.moonbitlang.org/)
- [OpenTelemetry Protocol (OTLP)](https://opentelemetry.io/docs/reference/protocol/)
- [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
