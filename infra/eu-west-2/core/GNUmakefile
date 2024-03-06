SHELL = bash
REGION := global

default: all

keys:
	mkdir -p ./keys

tls:
	mkdir -p ./tls

keys/bench-core.pem: keys *.tf
	terraform output -raw ssh_key > ./$@
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
ssh: keys/bench-core.pem

.PHONY: clean
clean:
	rm -fr ./tls/* ./keys/*

.PHONY: all
all: mtls ssh
