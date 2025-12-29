run_all:
	moon run --target js cmd/main
	moon run --target native cmd/main

moon_check:
	moon check --target js
	moon check --target native
