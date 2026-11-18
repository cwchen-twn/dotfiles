# ---- rust: needs rustup/cargo (+ cargo-audit) ----
.PHONY: rust/init rust/tidy rust/lint rust/test rust/audit rust/build rust/updatedep
rust/init:
	cargo fetch
rust/tidy:
	cargo fmt --all
rust/lint:
	cargo clippy --all-targets --all-features -- -D warnings
rust/test:
	cargo test --all-features
rust/audit:
	cargo fmt --all --check
	cargo audit
rust/build:
	cargo build --release
rust/updatedep:
	cargo update
