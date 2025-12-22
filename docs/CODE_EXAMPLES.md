# Code Examples - HTTP POST Implementation

This document provides practical code examples for using the HTTP POST implementation.

## Basic Usage in MoonBit

### Example 1: Simple HTTP POST Request

```moonbit
fn send_http_request() -> Unit {
  let url = "http://localhost:4318/v1/traces"
  let body = "{\"resourceSpans\": []}"
  let headers = Map::new()

  match http_post_json(url, body, headers) {
    Ok(response) => {
      println("Success! Status: " + response.status_code.to_string())
      println("Response: " + response.body)
    }
    Err(error) => {
      println("Error: " + error.to_string())
    }
  }
}
```

### Example 2: HTTP POST with Custom Headers

```moonbit
fn send_with_auth() -> Unit {
  let url = "http://api.example.com/v1/traces"
  let body = "{\"data\": \"test\"}"
  
  // Create custom headers
  let headers = Map::new()
  headers.set("Authorization", "Bearer my-token")
  headers.set("X-Request-ID", "12345")

  match http_post_json(url, body, headers) {
    Ok(response) => {
      if response.status_code >= 200 && response.status_code < 300 {
        println("Request sent successfully")
      } else {
        println("HTTP Error: " + response.status_code.to_string())
      }
    }
    Err(error) => {
      println("Failed to send request: " + error.to_string())
    }
  }
}
```

### Example 3: Error Handling

```moonbit
fn handle_errors() -> Unit {
  let result = http_post_json(
    "http://localhost:4318/v1/traces",
    "{}",
    Map::new()
  )

  match result {
    Ok(response) => {
      match response.status_code {
        200 | 201 | 202 | 204 => {
          println("Success")
        }
        400 => {
          println("Bad request: " + response.body)
        }
        500 | 502 | 503 => {
          println("Server error, will retry")
        }
        _ => {
          println("Unexpected status: " + response.status_code.to_string())
        }
      }
    }
    Err(HttpError::TimeoutError) => {
      println("Request timed out after 30 seconds")
    }
    Err(HttpError::NetworkError(msg)) => {
      println("Network error: " + msg)
    }
    Err(HttpError::InvalidResponse(msg)) => {
      println("Invalid response: " + msg)
    }
  }
}
```

## Integration with OTLP Exporter

### Example 4: Export Spans to OTLP Collector

```moonbit
fn export_spans_example() -> Unit {
  // Create a resource
  let resource = Resource::new()
    .with_attribute("service.name", "my-service")
    .with_attribute("service.version", "1.0.0")

  // Create a tracer
  let tracer = Tracer::new("my-tracer", resource)

  // Create a span
  let span = tracer.create_span("example-operation")
  span.add_attribute("key", "value")

  // Create OTLP exporter
  let config = OTLPExporterConfig::default()
    .with_endpoint("http://localhost:4318/v1/traces")
    .with_header("Authorization", "Bearer token")

  let exporter = OTLPExporter::new(config)

  // Export spans - this will make HTTP POST request via FFI
  exporter.export_spans([span])
}
```

### Example 5: OTLP Exporter with Custom Configuration

```moonbit
fn custom_otlp_config() -> Unit {
  let config = OTLPExporterConfig::default()
    .with_endpoint("https://api.example.com/v1/traces")
    .with_timeout(60000)  // 60 second timeout
    .with_header("Authorization", "Bearer my-secret-token")
    .with_header("X-API-Key", "api-key-123")

  let exporter = OTLPExporter::new(config)

  // Create and export spans...
}
```

## Node.js Integration

### Example 6: Setting Up FFI in Node.js

```javascript
// server.js
const { ffiHttpPost } = require('./http_ffi.js');
const express = require('express');

// Set up global FFI binding
globalThis.ffiHttpPost = ffiHttpPost;

// Load compiled MoonBit module
const otel = require('./compiled-moonbit.js');

const app = express();

// Create tracer
const resource = otel.createResource()
  .withAttribute('service.name', 'my-app');

const tracer = otel.createTracer(resource);

app.get('/', (req, res) => {
  const span = tracer.createSpan('http-request');
  span.addAttribute('http.method', 'GET');
  span.addAttribute('http.path', '/');

  // ... handle request ...

  res.send('Hello World');
  span.end();
});

app.listen(3000, () => {
  console.log('Server running with OpenTelemetry tracing');
  // Spans will be exported via HTTP to OTLP collector
});
```

### Example 7: Express.js Middleware

```javascript
// otel-middleware.js
const { ffiHttpPost } = require('./http_ffi.js');
const otel = require('./compiled-moonbit.js');

// Initialize once
globalThis.ffiHttpPost = ffiHttpPost;

const resource = otel.createResource()
  .withAttribute('service.name', 'express-app');

const tracer = otel.createTracer(resource);

module.exports = (req, res, next) => {
  const span = tracer.createSpan('express-' + req.method + '-' + req.path);

  span.addAttribute('http.method', req.method);
  span.addAttribute('http.url', req.originalUrl);
  span.addAttribute('http.client_ip', req.ip);

  // Record response when it's sent
  const originalSend = res.send;
  res.send = function(data) {
    span.addAttribute('http.status_code', res.statusCode);
    span.addAttribute('http.response_size', 
      typeof data === 'string' ? data.length : JSON.stringify(data).length
    );
    
    // Continue to next middleware/route
    originalSend.call(this, data);
  };

  next();
};
```

### Example 8: Testing HTTP Functionality

```javascript
// test-http.js
const { ffiHttpPost } = require('./http_ffi.js');
const http = require('http');

// Start a mock HTTP server for testing
const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/v1/traces') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      console.log('Received traces:', body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
    });
  }
});

server.listen(4318, () => {
  console.log('Test server listening on port 4318');

  // Test the FFI function
  const response = ffiHttpPost(
    'http://localhost:4318/v1/traces',
    JSON.stringify({
      resourceSpans: [{
        scopeSpans: []
      }]
    }),
    JSON.stringify({ 'Content-Type': 'application/json' })
  );

  console.log('FFI Response:', response);

  // Parse response
  try {
    const parsed = JSON.parse(response);
    console.log('Status Code:', parsed.status_code);
    console.log('Body:', parsed.body);
  } catch (e) {
    console.log('Error Response:', response);
  }

  server.close();
});
```

## Advanced Examples

### Example 9: Retry Logic (Manual Implementation)

```moonbit
fn http_post_with_retry(
  url : String,
  body : String,
  headers : Map[String, String],
  max_retries : Int,
) -> Result[HttpResponse, HttpError] {
  let mut attempts = 0
  let mut last_error = HttpError::NetworkError("No attempts made")

  while attempts < max_retries {
    match http_post_json(url, body, headers) {
      Ok(response) => {
        if response.status_code >= 200 && response.status_code < 300 {
          return Ok(response)
        } else if response.status_code >= 500 {
          // Retry on server errors
          last_error = HttpError::NetworkError(
            "Server error: " + response.status_code.to_string()
          )
          attempts = attempts + 1
        } else {
          // Don't retry on client errors
          return Ok(response)
        }
      }
      Err(error) => {
        last_error = error
        attempts = attempts + 1
      }
    }
  }

  Err(last_error)
}
```

### Example 10: Batch Export with Error Handling

```moonbit
fn export_spans_batch(
  exporter : OTLPExporter,
  spans : Array[Span],
  batch_size : Int,
) -> Unit {
  let mut i = 0
  while i < spans.length() {
    let end = if i + batch_size < spans.length() {
      i + batch_size
    } else {
      spans.length()
    }

    let batch = Array::new(end - i)
    for j in i..<end {
      batch[j - i] = spans[j]
    }

    match exporter.export_spans(batch) {
      Ok(_) => {
        println("Exported batch " + (i / batch_size + 1).to_string())
      }
      Err(error) => {
        println("Error exporting batch: " + error.to_string())
      }
    }

    i = end
  }
}
```

## Debugging Examples

### Example 11: Debug HTTP Requests

```moonbit
fn debug_http_request(
  url : String,
  body : String,
  headers : Map[String, String],
) -> Unit {
  println("=== HTTP Request Debug ===")
  println("URL: " + url)
  println("Body: " + body)
  println("Headers:")
  headers.each(fn(k, v) {
    println("  " + k + ": " + v)
  })

  match http_post_json(url, body, headers) {
    Ok(response) => {
      println("=== Response ===")
      println("Status: " + response.status_code.to_string())
      println("Body: " + response.body)
    }
    Err(error) => {
      println("=== Error ===")
      println("Type: " + error.to_string())
    }
  }
}
```

### Example 12: Monitor HTTP Performance

```javascript
// monitor-http.js
const { ffiHttpPost } = require('./http_ffi.js');

function measureHttpRequest(url, body, headers) {
  const startTime = Date.now();
  
  const response = ffiHttpPost(url, body, headers);
  
  const duration = Date.now() - startTime;
  
  try {
    const parsed = JSON.parse(response);
    console.log(`HTTP Request completed in ${duration}ms`);
    console.log(`Status: ${parsed.status_code || 'error'}`);
    console.log(`Response size: ${parsed.body?.length || 0} bytes`);
  } catch (e) {
    console.log(`HTTP Request failed after ${duration}ms`);
    console.log(`Error: ${response}`);
  }
}
```

## Summary

These examples show:
- Basic HTTP POST operations
- Custom headers and authentication
- Error handling patterns
- OTLP exporter integration
- Node.js FFI setup
- Express middleware integration
- Testing strategies
- Retry logic
- Batch processing
- Debugging and monitoring

For more details, see:
- [FFI_IMPLEMENTATION.md](FFI_IMPLEMENTATION.md) - Technical architecture
- [FFI_SETUP_GUIDE.md](FFI_SETUP_GUIDE.md) - Integration guide
