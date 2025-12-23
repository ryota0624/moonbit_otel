# ffi実装時のルール

## javascript ffi

.jsファイルを作らない。

https://docs.moonbitlang.com/en/latest/language/ffi.html を参考にする
 
以下のようにmbtの関数へ文字列で実装を埋め込む

```
extern "js" fn http_post_impl(request_json : String, timeout_ms: Int, resolve: (String) -> Unit) -> Unit = 
#| (requestJson, timeoutMs, resolve) => 
```