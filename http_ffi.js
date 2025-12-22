/**
 * Node.js FFI module for HTTP POST requests
 * This module handles HTTP requests using the native fetch API
 * Called from MoonBit via FFI bridge
 */

/**
 * Make an HTTP POST request using fetch API
 * @param {string} url - The target URL
 * @param {string} body - The request body (JSON string)
 * @param {string} headersJson - Headers as JSON string
 * @returns {string} Response as JSON string with format: {"status_code": 200, "body": "..."} or {"error": "message"}
 */
function ffiHttpPost(url, body, headersJson) {
  try {
    // Parse headers from JSON string
    let headers;
    try {
      headers = JSON.parse(headersJson);
    } catch (e) {
      headers = {};
    }

    // Ensure we have content-type header
    if (!headers['Content-Type']) {
      headers['Content-Type'] = 'application/json';
    }

    // Make the fetch request with timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout

    return fetch(url, {
      method: 'POST',
      headers: headers,
      body: body,
      signal: controller.signal,
    })
      .then(response => {
        clearTimeout(timeoutId);
        return response.text().then(text => {
          return JSON.stringify({
            status_code: response.status,
            body: text,
          });
        });
      })
      .catch(error => {
        clearTimeout(timeoutId);
        let errorMessage = 'Unknown error';

        if (error.name === 'AbortError') {
          errorMessage = 'Request timeout';
        } else if (error instanceof TypeError) {
          errorMessage = 'Network error: ' + error.message;
        } else {
          errorMessage = error.message || String(error);
        }

        return JSON.stringify({
          error: errorMessage,
        });
      });
  } catch (error) {
    return JSON.stringify({
      error: 'Unexpected error: ' + (error?.message || String(error)),
    });
  }
}

// Export for Node.js
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    ffiHttpPost,
  };
}

// Export for browser/FFI
if (typeof globalThis !== 'undefined') {
  globalThis.ffiHttpPost = ffiHttpPost;
}
