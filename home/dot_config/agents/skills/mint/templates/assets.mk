# Media targets (mint skill). Copy into the app Makefile or `include` it.
# They write committed files and are never part of `audit` or CI.
ICON_OUT ?= public/icons

.PHONY: assets/build assets/icons
assets/build: ## Generate the media in assets/manifest.yaml that doesn't exist yet (mint)
	@command -v yq >/dev/null || { echo 'assets/build needs yq (project mise.toml: yq = "latest")'; exit 1; }
	@yq -o=json '.[]' assets/manifest.yaml | jq -c . | while read -r e; do \
	  out=$$(echo "$$e" | jq -r .out); [ -e "$$out" ] && continue; \
	  set -- "$$(echo "$$e" | jq -r .kind)" --prompt "$$(echo "$$e" | jq -r .prompt)" --out "$$out"; \
	  a=$$(echo "$$e" | jq -r '.aspect // empty'); [ -z "$$a" ] || set -- "$$@" --aspect "$$a"; \
	  d=$$(echo "$$e" | jq -r '.duration // empty'); [ -z "$$d" ] || set -- "$$@" --duration "$$d"; \
	  for r in $$(echo "$$e" | jq -r '.refs // [] | .[]'); do set -- "$$@" --ref "$$r"; done; \
	  mint "$$@" </dev/null || exit 1;  # not the loop's stdin: a child reading it would end the loop \
	done

assets/icons: ## Derive every icon size from assets/src/icon.png into $(ICON_OUT)
	mint icons assets/src/icon.png $(ICON_OUT)
