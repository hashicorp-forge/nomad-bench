.PHONY: deps
deps:  ## Install build and development dependencies
	@echo "==> Installing Python dependencies..."
	@pip install -r ./shared/ansible/requirements.txt
	@echo "==> Installing Ansible Galaxy dependencies..."
	@ansible-galaxy install -r ./shared/ansible/requirements.yaml
