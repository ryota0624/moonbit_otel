build:
	moon build --no-strip -g --target wasm ./gen
	wasm-tools component embed wit target/wasm/debug/build/gen/gen.wasm -o target/wasm/debug/build/gen/gen.wasm --encoding utf16 -g
	wasm-tools component new target/wasm/debug/build/gen/gen.wasm -o target/wasm/debug/build/gen/gen.wasm -g

run: build
	wasmtime -S http -S cli target/wasm/debug/build/gen/gen.wasm