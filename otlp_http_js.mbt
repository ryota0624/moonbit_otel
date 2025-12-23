// FFI function for HTTP POST using JavaScript's fetch API
// Input: JSON string containing HttpRequest { url, http_method, headers, body }
// Output: JSON string containing HttpResponse { status_code, body }
//
// This function is imported from the JavaScript global scope (otel module)
// You must define this in your JavaScript runtime before using MoonBit
extern "js" fn http_post_impl(request_json : String, resolve: (String) -> Unit , reject: (String) -> Unit) -> String = 
#| (requestJson) => {
#|   try {
#|     // Parse the request from MoonBit
#|     const request = JSON.parse(requestJson);
#|     const { url, http_method, headers, body } = request;
#|     // Set timeout for the fetch request (30 seconds by default)
#|     const controller = new AbortController();
#|     const timeoutId = setTimeout(() => controller.abort(), 30000);
#|     // Make the fetch request and return promise that resolves to JSON string
#|     return fetch(url, {
#|       method: http_method || "POST",
#|       headers: headers || { "Content-Type": "application/json" },
#|       body: body,
#|       signal: controller.signal,
#|     })
#|       .then(response => {
#|         clearTimeout(timeoutId);
#|         // Read the response body
#|         return response.text().then(responseBody => {
#|           const result = {
#|             status_code: response.status,
#|             body: responseBody,
#|           };
#|           return JSON.stringify(result);
#|         });
#|       })
#|       .then(resolve)
#|       .catch(error => {
#|         clearTimeout(timeoutId);
#|         // Handle different error types
#|         let errorBody = "Unknown error";
#|         if (error.name === "AbortError") {
#|           errorBody = "Request timeout";
#|         } else if (error instanceof TypeError) {
#|           errorBody = `Network error: ${error.message}`;
#|         } else {
#|           errorBody = `Error: ${error.message}`;
#|         }
#|         const errorResponse = {
#|           status_code: 0,
#|           body: errorBody,
#|         };
#|         reject(JSON.stringify(errorResponse));
#|       });
#|   } catch (error) {
#|     // Handle JSON parsing errors
#|     const errorResponse = {
#|       status_code: 0,
#|       body: `Invalid request format: ${error.message}`,
#|     };
#|     return reject(errorResponse);
#|   }
#| }
