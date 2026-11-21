# ---- release: for repos whose Git profile sets `tags: vX.Y.Z`; copy templates/release.sh to scripts/ ----
##release: Preview the vX.Y.Z tag, and with confirm=yes tag main and push - make release version=X.Y.Z summary="..."
.PHONY: release
release:
	@test -n "$(version)" || { echo 'usage: make release version=X.Y.Z summary="..." [confirm=yes]'; exit 1; }
	./scripts/release.sh "$(version)" "$(summary)" "$(confirm)"
##dist: Build the files the release page attaches into dist/ (for release page; set the recipe per stack)
.PHONY: dist
dist: build
	mkdir -p dist
	@echo "dist: copy the release files into dist/ here (e.g. cp bin/* dist/)"; exit 1
