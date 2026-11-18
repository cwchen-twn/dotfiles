# ---- helm: needs helm (mise) + the helm-diff plugin; one dir per chart under CHARTS_DIR ----
CHARTS_DIR := charts
.PHONY: helm/init helm/tidy helm/lint helm/test helm/audit helm/build helm/updatedep
helm/init:
	for c in $(CHARTS_DIR)/*/; do helm dependency build "$$c" || exit 1; done
helm/lint:
	for c in $(CHARTS_DIR)/*/; do helm lint "$$c" || exit 1; done
helm/test:
	for c in $(CHARTS_DIR)/*/; do helm template "$$c" >/dev/null || exit 1; done
helm/tidy helm/audit helm/build:
	@:
helm/updatedep:
	for c in $(CHARTS_DIR)/*/; do helm dependency update "$$c" || exit 1; done
##diff: Show what a chart upgrade would change, e.g. `make diff chart=gitea` (read-only)
.PHONY: diff
diff:
	@test -n "$(chart)" || { echo "usage: make diff chart=<name>"; exit 1; }
	helm diff upgrade $(chart) $(CHARTS_DIR)/$(chart) -n $(chart) -f $(CHARTS_DIR)/$(chart)/values.yaml
##deploy/chart: Upgrade one chart, e.g. `make deploy/chart chart=gitea confirm=yes`
.PHONY: deploy/chart
deploy/chart:
	@test -n "$(chart)" || { echo "usage: make deploy/chart chart=<name> confirm=yes"; exit 1; }
	@test "$(confirm)" = yes || { echo "this deploys $(chart): add confirm=yes"; exit 1; }
	helm upgrade --install $(chart) $(CHARTS_DIR)/$(chart) -n $(chart) --create-namespace --atomic --wait -f $(CHARTS_DIR)/$(chart)/values.yaml
