build:
	moon build --target wasm ./gen
	wasm-tools component embed wit target/wasm/release/build/gen/gen.wasm -o target/wasm/release/build/gen/gen.wasm --encoding utf16
	wasm-tools component new target/wasm/release/build/gen/gen.wasm -o target/wasm/release/build/gen/gen.wasm

run: build
	wasmtime -S http -S cli ./target/wasm/release/build/gen/gen.wasm