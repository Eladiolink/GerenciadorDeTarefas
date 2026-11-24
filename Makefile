# Atalhos para o ambiente de desenvolvimento (hot reload) e producao.
# Uso: make help
#
# O hot reload funciona com o override docker-compose.dev.yml: um watcher
# inotify recompila o codigo a cada save e o Spring DevTools reinicia a API.

ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
COMPOSE_DEV := docker compose --project-directory $(ROOT) -f $(ROOT)/docker-compose.yml -f $(ROOT)/docker-compose.dev.yml
COMPOSE_PROD := docker compose --project-directory $(ROOT) -f $(ROOT)/docker-compose.yml

SERVICE ?= user-service

.DEFAULT_GOAL := help
.PHONY: help env dev dev-up dev-down dev-restart prod prod-up prod-down down logs logs-service ps compile shell ping

help: ## Mostra esta ajuda
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

env: ## Cria .env a partir de .env.example (se ainda nao existir)
	@test -f $(ROOT)/.env || cp $(ROOT)/.env.example $(ROOT)/.env

dev: dev-up ## Alias para dev-up

dev-up: env ## Sobe tudo com hot reload (recompila ao salvar .java)
	$(COMPOSE_DEV) up -d --build

dev-down: ## Para os containers do stack (dados dos bancos preservados)
	$(COMPOSE_DEV) down

dev-restart: dev-down dev-up ## Reinicia o ambiente de desenvolvimento

prod: prod-up ## Alias para prod-up

prod-up: env ## Sobe com os jars empacotados (sem hot reload)
	$(COMPOSE_PROD) up -d --build

prod-down: ## Para os containers do stack (dados dos bancos preservados)
	$(COMPOSE_PROD) down

down: dev-down ## Alias para dev-down

ps: ## Mostra o status dos containers
	$(COMPOSE_DEV) ps

logs: ## Acompanha os logs de todos os servicos
	$(COMPOSE_DEV) logs -f

logs-service: ## Logs de um servico (SERVICE=user-service)
	$(COMPOSE_DEV) logs -f $(SERVICE)

compile: ## Forca mvn compile em um servico (SERVICE=user-service)
	$(COMPOSE_DEV) exec $(SERVICE) mvn -q compile

shell: ## Abre um shell no container de um servico (SERVICE=user-service)
	$(COMPOSE_DEV) exec $(SERVICE) bash

ping: ## Testa o endpoint /user/ping pelo API Gateway
	@curl -s -w ' HTTP %{http_code}\n' http://localhost:8080/user/ping
