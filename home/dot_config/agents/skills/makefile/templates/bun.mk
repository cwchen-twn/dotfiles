# ---- bun (JS/TS web): needs bun (mise); package.json scripts are wrapped, not called directly ----
WEB_DIR := .
.PHONY: bun/init bun/tidy bun/lint bun/test bun/audit bun/build bun/updatedep
bun/init:
	cd $(WEB_DIR) && bun install --frozen-lockfile
bun/tidy:
	cd $(WEB_DIR) && bun run format
bun/lint:
	cd $(WEB_DIR) && bun run lint
	cd $(WEB_DIR) && bunx tsc --noEmit
bun/test:
	cd $(WEB_DIR) && bun test
bun/audit:
	cd $(WEB_DIR) && bun audit
bun/build:
	cd $(WEB_DIR) && bun run build
bun/updatedep:
	cd $(WEB_DIR) && bun update --latest
##run/live: Dev server with hot reload
.PHONY: run/live
run/live:
	cd $(WEB_DIR) && bun run dev
##test/e2e: Playwright end-to-end specs
.PHONY: test/e2e
test/e2e:
	cd $(WEB_DIR) && bunx playwright test
