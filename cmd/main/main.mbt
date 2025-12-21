///|
fn main {
  // Demonstrate Context usage
  let ctx = @lib.Context::empty()
    .with_string("request_id", "12345")
    .with_int("user_id", 42)
  let ctx_size = ctx.size()
  let request_id = ctx.get_string("request_id")
  println("Context size: \{ctx_size}")
  println("Request ID: \{request_id}")

  // Demonstrate Resource usage
  let resource = @lib.Resource::empty()
    .with_string(@lib.service_name, "my-service")
    .with_string(@lib.service_version, "1.0.0")
  let res_size = resource.size()
  let svc_name = resource.get_string(@lib.service_name)
  println("Resource size: \{res_size}")
  println("Service name: \{svc_name}")
}
