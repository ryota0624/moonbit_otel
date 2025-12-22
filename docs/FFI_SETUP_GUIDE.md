# FFI Setup Guide - How to Integrate HTTP POST with Node.js

This guide walks through setting up the FFI binding between MoonBit and Node.js for HTTP requests.

## Quick Start

### Step 1: Ensure Files Are In Place

Make sure you have:
- [otlp_http.mbt](otlp_http.mbt) - MoonBit implementation
- [http_ffi.js](http_ffi.js) - JavaScript implementation

### Step 2: Compile MoonBit to JavaScript

```bash
# Compile to JavaScript target
moon build --target js

# Or build to wasm if targeting JavaScript runtime with wasm loader
moon build --target wasm-gc
```

### Step 3: Set Up Your Node.js Project

#### Option A: Using CommonJS

```javascript
// your-app.js
const httpFfi = require('./http_ffi.js');

// Make FFI function available globally
globalThis.ffiHttpPost = httpFfi.ffiHttpPost;

// Load your MoonBit-compiled module
const myModule = require('./path-to-compiled-moonbit.js');
```

#### Option B: Using ES Modules

```javascript
// your-app.mjs
import { ffiHttpPost } from './http_ffi.js';

// Make FFI function available globally
globalThis.ffiHttpPost = ffiHttpPost;

// Load your MoonBit-compiled module
import myModule from './path-to-compiled-moonbit.js';
```

#### Option C: Using a Bundler (Webpack/Rollup)

```javascript
// webpack.config.js
module.exports = {
  entry: './src/main.js',
  output: {
    filename: 'bundle.js',
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
      },
    ],
  },
  // Tell webpack about the FFI module
  externals: {
    'http-ffi': 'globalThis.ffiHttpPost',
  },
};
```

### Step 4: Use in Your Application

```javascript
// Once FFI is set up, you can call the exported functions
const otlp = myModule.createOTLPExporter({
  endpoint: 'http://localhost:4318/v1/traces',
});

// Export spans - HTTP calls will work via FFI
otlp.exportSpans(spans);
```

## Different Integration Scenarios

### Scenario 1: Node.js CLI Application

```javascript
#!/usr/bin/env node
// cli.js

const { ffiHttpPost } = require('./http_ffi.js');

// Set up global
globalThis.ffiHttpPost = ffiHttpPost;

// Now load your compiled MoonBit module
const otel = require('./compiled-moonbit/moonbit_otel.js');

// Use OTLP exporter
const resource = otel.createResource();
const tracer = otel.createTracer(resource);
const span = tracer.createSpan('my-span');
// ... use tracer and spans
```

### Scenario 2: Express.js Middleware

```javascript
// middleware.js
const { ffiHttpPost } = require('./http_ffi.js');
const otel = require('./compiled-moonbit/moonbit_otel.js');

// Set up FFI globally once
globalThis.ffiHttpPost = ffiHttpPost;

// Create tracer once
const resource = otel.createResource();
const tracer = otel.createTracer(resource);

module.exports = (req, res, next) => {
  const span = tracer.createSpan(req.path);
  span.addAttribute('http.method', req.method);
  span.addAttribute('http.target', req.path);

  res.on('finish', () => {
    span.addAttribute('http.status_code', res.statusCode);
    // Exporting spans will use HTTP via FFI
  });

  next();
};
```

### Scenario 3: Browser-based Application (with Polyfill)

```html
<!-- index.html -->
<script src="https://unpkg.com/node-fetch"></script>
<script src="./http_ffi.js"></script>
<script src="./compiled-moonbit.js"></script>
<script>
  // FFI function should be available globally now
  const otel = window.moonbitModule.otel;
  const exporter = otel.createOTLPExporter();
  // Use it...
</script>
```

## Troubleshooting

### Problem: "ffiHttpPost is not defined"

**Solution**: Ensure you're setting it globally before using it:
```javascript
globalThis.ffiHttpPost = require('./http_ffi.js').ffiHttpPost;
```

### Problem: "HTTP request timeout"

**Solution**: The FFI implementation has a 30-second timeout. To change it, edit `http_ffi.js`:
```javascript
const timeoutMs = 60000; // Change to 60 seconds
const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
```

### Problem: "Cannot find module 'http_ffi.js'"

**Solution**: Make sure the file path is correct relative to your Node.js working directory:
```javascript
// Use absolute paths if needed
const httpFfi = require(path.join(__dirname, './http_ffi.js'));
```

### Problem: "Content-Type header not set"

**Solution**: The FFI implementation automatically sets Content-Type. If you need custom headers:
```moonbit
let headers = Map::new()
headers.set("Authorization", "Bearer token")
headers.set("X-Custom-Header", "value")
// Content-Type will be automatically set to application/json if not provided
http_post_json(url, body, headers)
```

## Performance Considerations

1. **Connection Reuse**: Each HTTP call creates a new fetch request. Consider implementing connection pooling for high-throughput scenarios.

2. **Memory Usage**: JSON string conversion happens character-by-character. For large payloads, this may be slower than direct JSON serialization.

3. **Timeout**: The 30-second timeout is a good default for OTLP endpoints but can be adjusted based on your needs.

## Advanced Customization

### Custom HTTP Headers

```moonbit
let headers = Map::new()
headers.set("Authorization", "Bearer my-token")
headers.set("X-Custom-Header", "my-value")

let result = http_post_json(
  "http://localhost:4318/v1/traces",
  json_body,
  headers
)
```

### Error Handling

```moonbit
match result {
  Ok(response) => {
    if response.status_code >= 200 && response.status_code < 300 {
      println("Success: " + response.status_code.to_string())
    } else {
      println("HTTP Error: " + response.status_code.to_string())
      println("Response: " + response.body)
    }
  }
  Err(HttpError::TimeoutError) => {
    println("Request timed out")
  }
  Err(HttpError::NetworkError(msg)) => {
    println("Network error: " + msg)
  }
  Err(HttpError::InvalidResponse(msg)) => {
    println("Invalid response: " + msg)
  }
}
```

### Custom Timeout

To modify the timeout, edit [http_ffi.js](http_ffi.js):

```javascript
// Line 24 - change timeout duration
const timeoutMs = 60000; // 60 seconds instead of 30
const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
```

## Testing the Integration

### Test 1: Basic HTTP Request

```javascript
const { ffiHttpPost } = require('./http_ffi.js');

// Test the raw FFI function
const response = ffiHttpPost(
  'https://httpbin.org/post',
  JSON.stringify({ test: true }),
  JSON.stringify({ 'Content-Type': 'application/json' })
);

console.log('Response:', response);
```

### Test 2: With MoonBit Module

```javascript
globalThis.ffiHttpPost = require('./http_ffi.js').ffiHttpPost;

const otel = require('./compiled-moonbit.js');

// Create and export a test span
const exporter = otel.OTLPExporter.default();
const spans = [/* ... test span ... */];
exporter.exportSpans(spans);
```

### Test 3: Mock HTTP Server

For testing without external dependencies:

```javascript
const http = require('http');
const { ffiHttpPost } = require('./http_ffi.js');

// Start a mock server
const server = http.createServer((req, res) => {
  if (req.method === 'POST') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: true }));
  }
});

server.listen(4318, () => {
  // Now test against local server
  const response = ffiHttpPost(
    'http://localhost:4318/v1/traces',
    '{}',
    '{}'
  );
  console.log('Test response:', response);
  server.close();
});
```

## Next Steps

1. **Compile your MoonBit code** to JavaScript target
2. **Test the FFI binding** with a simple example
3. **Integrate with your Node.js application**
4. **Monitor HTTP requests** using your application's logging/monitoring tools
5. **Optimize** timeout and retry settings for your use case

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review [FFI_IMPLEMENTATION.md](FFI_IMPLEMENTATION.md) for architecture details
3. Verify your MoonBit compilation output
4. Test the raw FFI function independently from MoonBit code
