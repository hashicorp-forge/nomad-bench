SHELL = bash
REGION := global
SSH_KEY_NAME := $(shell terraform output -raw ssh_key_name).pem

default: all

keys:
	mkdir -p ./keys

tls:
	mkdir -p ./tls

keys/$(SSH_KEY_NAME): keys *.tf
	terraform output -raw ssh_key > ./keys/$(SSH_KEY_NAME)
	chmod 0600 ./$@

tls/nomad-agent-ca.pem: tls *.tf
	terraform output -raw ca_cert > ./$@

TLS_TARGETS = cli client server
define makeTLSTarget

tls/$(REGION)-$(1)-nomad.pem: tls *.tf
	terraform output -raw $(1)_cert > ./$$@

tls/$(REGION)-$(1)-nomad-key.pem: tls *.tf
	terraform output -raw $(1)_key > ./$$@

endef
$(foreach t,$(TLS_TARGETS),$(eval $(call makeTLSTarget,$(t))))

.PHONY: mtls
mtls: tls/nomad-agent-ca.pem
mtls: $(foreach t,$(TLS_TARGETS),tls/$(REGION)-$(t)-nomad.pem)
mtls: $(foreach t,$(TLS_TARGETS),tls/$(REGION)-$(t)-nomad-key.pem)

.PHONY: ssh
ssh: keys/$(SSH_KEY_NAME)

.PHONY: clean
clean:
	rm -fr ./tls/* ./keys/*

.PHONY: all
all: mtls ssh
