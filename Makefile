K8S_NAMESPACE ?= banking
K8S_APP_PORT ?= 8080
K8S_DB_PORT ?= 15432
K8S_PROMETHEUS_PORT ?= 9090
K8S_GRAFANA_PORT ?= 3000
K8S_BASE_URL ?= http://localhost:$(K8S_APP_PORT)
K8S_DB_DSN ?= postgres://postgres:postgres@localhost:$(K8S_DB_PORT)/banking?sslmode=disable
CLOUD_TF_DIR ?= deployments/terraform/cloud-demo
CLOUD_ANSIBLE_DIR ?= deployments/ansible
CLOUD_INVENTORY ?= $(CLOUD_ANSIBLE_DIR)/inventory/hosts.ini
CLOUD_SEED ?= true
CLOUD_LOAD_TEST ?= mixed
CLOUD_WAIT_ATTEMPTS ?= 30
TF ?= terraform
ANSIBLE ?= ansible
ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_CONFIG := $(CURDIR)/$(CLOUD_ANSIBLE_DIR)/ansible.cfg

.PHONY: dev lint fmt test build seed \
        up up-optimized down logs ps \
        k8s-up k8s-down k8s-status k8s-logs \
        k8s-port-forward k8s-port-forward-db \
        k8s-port-forward-prometheus k8s-port-forward-grafana \
        k8s-seed k8s-load-test \
        cloud-init cloud-plan cloud-apply cloud-wait cloud-configure \
        cloud-demo cloud-update cloud-status cloud-health cloud-load-test cloud-load-status \
        cloud-load-spike cloud-load-optimized cloud-stop-load-test cloud-logs \
        cloud-destroy cloud-cleanup

init:
	go mod download
	go install github.com/air-verse/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

dev:
	air

lint:
	golangci-lint-v2 run

test:
	go test -v ./...

build:
	go build -o bin/app cmd/server/main.go

ifeq ($(OS),Windows_NT) # Windows' command
seed:
	set DB_PRIMARY_DSN=postgres://postgres:postgres@localhost:5432/banking?sslmode=disable&& go run ./cmd/seeds/main.go
else
seed:
	DB_PRIMARY_DSN=postgres://postgres:postgres@localhost:5432/banking?sslmode=disable go run ./cmd/seeds/main.go
endif

up:
	cp .env.baseline.example .env
	docker compose up -d --build

up-optimized:
	cp .env.optimized.example .env
	docker compose --profile optimized up -d --build

down:
	docker compose --profile optimized down

load-test:
	k6 run scripts/load-test/mixed.js

logs:
	docker compose logs -f

ps:
	docker compose ps

k8s-up:
	kubectl apply -f deployments/k8s/namespace.yaml
	kubectl apply -f deployments/k8s/

k8s-down:
	kubectl delete -f deployments/k8s/ --ignore-not-found
	kubectl delete -f deployments/k8s/namespace.yaml --ignore-not-found

k8s-status:
	kubectl -n $(K8S_NAMESPACE) get pods,svc,hpa

k8s-logs:
	kubectl -n $(K8S_NAMESPACE) logs -f deploy/banking-app

k8s-port-forward:
	kubectl -n $(K8S_NAMESPACE) port-forward svc/banking-app $(K8S_APP_PORT):8080

k8s-port-forward-db:
	kubectl -n $(K8S_NAMESPACE) port-forward svc/postgres $(K8S_DB_PORT):5432

k8s-port-forward-prometheus:
	kubectl -n $(K8S_NAMESPACE) port-forward svc/prometheus $(K8S_PROMETHEUS_PORT):9090

k8s-port-forward-grafana:
	kubectl -n $(K8S_NAMESPACE) port-forward svc/grafana $(K8S_GRAFANA_PORT):3000

k8s-seed:
	DB_PRIMARY_DSN=$(K8S_DB_DSN) go run ./cmd/seeds/main.go

k8s-load-test:
	BASE_URL=$(K8S_BASE_URL) k6 run scripts/load-test/mixed.js

cloud-init:
	$(TF) -chdir=$(CLOUD_TF_DIR) init

cloud-plan:
	$(TF) -chdir=$(CLOUD_TF_DIR) plan

cloud-apply:
	$(TF) -chdir=$(CLOUD_TF_DIR) apply -auto-approve

cloud-wait:
	@for attempt in $$(seq 1 $(CLOUD_WAIT_ATTEMPTS)); do \
		if ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE) all -i $(CURDIR)/$(CLOUD_INVENTORY) -m ping >/dev/null 2>&1; then \
			echo "Cloud hosts are reachable."; \
			exit 0; \
		fi; \
		echo "Waiting for cloud SSH... $$attempt/$(CLOUD_WAIT_ATTEMPTS)"; \
		sleep 10; \
	done; \
	echo "Timed out waiting for cloud SSH."; \
	exit 1

cloud-configure:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE_PLAYBOOK) -i $(CURDIR)/$(CLOUD_INVENTORY) $(CLOUD_ANSIBLE_DIR)/main.yml -e seed=$(CLOUD_SEED)

cloud-demo: cloud-init cloud-apply cloud-wait cloud-configure cloud-status

cloud-update:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE_PLAYBOOK) -i $(CURDIR)/$(CLOUD_INVENTORY) $(CLOUD_ANSIBLE_DIR)/playbooks/05-deploy.yml

cloud-status:
	$(TF) -chdir=$(CLOUD_TF_DIR) output
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE_PLAYBOOK) -i $(CURDIR)/$(CLOUD_INVENTORY) $(CLOUD_ANSIBLE_DIR)/playbooks/03-show-evidence.yml

cloud-health: cloud-status

cloud-load-test:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE_PLAYBOOK) -i $(CURDIR)/$(CLOUD_INVENTORY) $(CLOUD_ANSIBLE_DIR)/playbooks/04-load-test.yml -e loadtest_name=$(CLOUD_LOAD_TEST)

cloud-load-status:
	$(MAKE) cloud-load-test CLOUD_LOAD_TEST=status

cloud-load-spike:
	$(MAKE) cloud-load-test CLOUD_LOAD_TEST=spike

cloud-load-optimized:
	$(MAKE) cloud-load-test CLOUD_LOAD_TEST=optimized

cloud-stop-load-test:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE) k6_runners -i $(CURDIR)/$(CLOUD_INVENTORY) -m shell -a "pkill -TERM k6 || true; sleep 2; pkill -KILL k6 || true; pgrep -af k6 || true"

cloud-logs:
	ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) $(ANSIBLE) app_servers -i $(CURDIR)/$(CLOUD_INVENTORY) -b -m shell -a "cd /home/ubuntu/banking-peak-load-prototype && docker compose logs --tail=120 app postgres pgbouncer prometheus grafana"

cloud-destroy:
	$(TF) -chdir=$(CLOUD_TF_DIR) destroy -auto-approve

cloud-cleanup: cloud-destroy
