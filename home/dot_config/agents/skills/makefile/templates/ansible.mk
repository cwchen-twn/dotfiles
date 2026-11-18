# ---- ansible: needs ansible + ansible-lint; the playbook is PLAYBOOK ----
PLAYBOOK := site.yml
.PHONY: ansible/init ansible/tidy ansible/lint ansible/test ansible/audit ansible/build ansible/updatedep
ansible/init:
	@if [ -f requirements.yml ]; then ansible-galaxy install -r requirements.yml; fi
ansible/lint:
	ansible-lint
	ansible-playbook --syntax-check $(PLAYBOOK)
ansible/tidy ansible/test ansible/audit ansible/build:
	@:
ansible/updatedep:
	@if [ -f requirements.yml ]; then ansible-galaxy install -r requirements.yml --force; fi
##check: Dry-run the playbook with a diff (read-only)
.PHONY: check
check:
	ansible-playbook --check --diff $(PLAYBOOK)
