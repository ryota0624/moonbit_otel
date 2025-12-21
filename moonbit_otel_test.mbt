// Tests for Context

///|
test "Context::empty creates an empty context" {
  let ctx = Context::empty()
  assert_eq(ctx.size(), 0)
}

///|
test "Context::with_string adds a string value" {
  let ctx = Context::empty().with_string("key1", "value1")
  assert_eq(ctx.get_string("key1"), Some("value1"))
  assert_eq(ctx.size(), 1)
}

///|
test "Context::with_int adds an int value" {
  let ctx = Context::empty().with_int("count", 42)
  assert_eq(ctx.get_int("count"), Some(42))
}

///|
test "Context::with_bool adds a bool value" {
  let ctx = Context::empty().with_bool("flag", true)
  assert_eq(ctx.get_bool("flag"), Some(true))
}

///|
test "Context::with_double adds a double value" {
  let ctx = Context::empty().with_double("pi", 3.14)
  assert_eq(ctx.get_double("pi"), Some(3.14))
}

///|
test "Context::get returns None for non-existent key" {
  let ctx = Context::empty()
  assert_eq(ctx.get_string("missing"), None)
}

///|
test "Context is immutable - original unchanged after with_string" {
  let ctx1 = Context::empty()
  let ctx2 = ctx1.with_string("key", "value")
  assert_eq(ctx1.size(), 0)
  assert_eq(ctx2.size(), 1)
}

///|
test "Context::contains checks key existence" {
  let ctx = Context::empty().with_string("key", "value")
  assert_true(ctx.contains("key"))
  assert_false(ctx.contains("missing"))
}

///|
test "Context can store multiple values" {
  let ctx = Context::empty()
    .with_string("name", "test")
    .with_int("count", 10)
    .with_bool("enabled", true)
  assert_eq(ctx.size(), 3)
  assert_eq(ctx.get_string("name"), Some("test"))
  assert_eq(ctx.get_int("count"), Some(10))
  assert_eq(ctx.get_bool("enabled"), Some(true))
}

// Tests for Resource

///|
test "Resource::empty creates an empty resource" {
  let res = Resource::empty()
  assert_eq(res.size(), 0)
}

///|
test "Resource::with_string adds a string attribute" {
  let res = Resource::empty().with_string(service_name, "my-service")
  assert_eq(res.get_string(service_name), Some("my-service"))
  assert_eq(res.size(), 1)
}

///|
test "Resource::with_int adds an int attribute" {
  let res = Resource::empty().with_int("port", 8080)
  assert_eq(res.get_int("port"), Some(8080))
}

///|
test "Resource::with_bool adds a bool attribute" {
  let res = Resource::empty().with_bool("debug", false)
  assert_eq(res.get_bool("debug"), Some(false))
}

///|
test "Resource::with_double adds a double attribute" {
  let res = Resource::empty().with_double("version", 1.5)
  assert_eq(res.get_double("version"), Some(1.5))
}

///|
test "Resource::with_string_array adds a string array attribute" {
  let res = Resource::empty().with_string_array("tags", ["prod", "web"])
  match res.get("tags") {
    Some(AttributeValue::StringArray(arr)) => assert_eq(arr, ["prod", "web"])
    _ => fail("Expected StringArray")
  }
}

///|
test "Resource is immutable - original unchanged after with_string" {
  let res1 = Resource::empty()
  let res2 = res1.with_string(service_name, "service1")
  assert_eq(res1.size(), 0)
  assert_eq(res2.size(), 1)
}

///|
test "Resource::contains checks attribute existence" {
  let res = Resource::empty().with_string(service_name, "my-service")
  assert_true(res.contains(service_name))
  assert_false(res.contains("missing"))
}

///|
test "Resource::merge combines two resources" {
  let res1 = Resource::empty()
    .with_string(service_name, "service1")
    .with_string(service_version, "1.0.0")
  let res2 = Resource::empty()
    .with_string(service_namespace, "production")
    .with_string(service_version, "2.0.0") // This should override
  let merged = res1.merge(res2)
  assert_eq(merged.size(), 3)
  assert_eq(merged.get_string(service_name), Some("service1"))
  assert_eq(merged.get_string(service_namespace), Some("production"))
  assert_eq(merged.get_string(service_version), Some("2.0.0")) // res2 takes precedence
}

///|
test "Resource can store multiple attribute types" {
  let res = Resource::empty()
    .with_string(service_name, "my-service")
    .with_int("port", 8080)
    .with_bool("debug", true)
    .with_double("cpu_limit", 2.5)
  assert_eq(res.size(), 4)
  assert_eq(res.get_string(service_name), Some("my-service"))
  assert_eq(res.get_int("port"), Some(8080))
  assert_eq(res.get_bool("debug"), Some(true))
  assert_eq(res.get_double("cpu_limit"), Some(2.5))
}
