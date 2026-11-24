# Gerenciador de Tarefas

Sistema de gerenciamento de tarefas baseado em microsserviços com **Java 25**, **Spring Boot 4.2.0** e **PostgreSQL 17**, totalmente containerizado com Docker Compose.

> **Status:** projeto em desenvolvimento. A estrutura dos microsserviços, os bancos de dados, o ambiente Docker, o roteamento do API Gateway e a autenticação JWT já estão funcionais; as regras de negócio ainda estão sendo implementadas.

## Sumário

- [Arquitetura](#arquitetura)
- [Tecnologias](#tecnologias)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Serviços e portas](#serviços-e-portas)
- [Pré-requisitos](#pré-requisitos)
- [Configuração](#configuração)
- [Como executar](#como-executar)
- [Desenvolvimento com hot reload](#desenvolvimento-com-hot-reload)
- [Testando os serviços](#testando-os-serviços)
- [Autenticação JWT](#autenticação-jwt)
- [Variáveis de ambiente](#variáveis-de-ambiente)
- [Decisões de arquitetura](#decisões-de-arquitetura)
- [Segurança](#segurança)
- [Roadmap](#roadmap)

## Arquitetura

```mermaid
flowchart LR
    Client([Cliente]) --> GW[API Gateway<br/>:8080]

    GW --> US[UserService<br/>:8081]
    GW --> TS[TaskService<br/>:8082]
    GW --> NS[NotificationService<br/>:8083]

    US --> UDB[(userdb<br/>PostgreSQL :5433)]
    TS --> TDB[(taskdb<br/>PostgreSQL :5434)]
    NS --> NDB[(notificationdb<br/>PostgreSQL :5435)]
```

- **API Gateway**: ponto de entrada único da aplicação.
- **UserService**: gerenciamento de usuários.
- **TaskService**: gerenciamento de tarefas.
- **NotificationService**: envio e registro de notificações.
- **Database per service**: cada microsserviço possui seu próprio banco PostgreSQL e volume persistente.

O API Gateway roteia pelo prefixo do path, preservando o caminho original:

| Prefixo no gateway | Serviço de destino | URI interna |
| --- | --- | --- |
| `/user/**` | `user-service` | `http://user-service:8080` |
| `/task/**` | `task-service` | `http://task-service:8080` |
| `/notification/**` | `notification-service` | `http://notification-service:8080` |

As URIs podem ser sobrescritas pelas variáveis `USER_SERVICE_URI`, `TASK_SERVICE_URI` e `NOTIFICATION_SERVICE_URI` (útil para rodar o gateway fora do Docker). Por enquanto, apenas o endpoint `/user/ping` do `UserService` está implementado.

## Tecnologias

| Categoria | Tecnologia |
| --- | --- |
| Linguagem | Java 25 |
| Framework | Spring Boot 4.2.0 |
| Cloud | Spring Cloud 2026.0.0-SNAPSHOT (Gateway Server WebMVC) |
| Persistência | Spring Data JPA / Hibernate |
| Banco de dados | PostgreSQL 17 (Alpine) |
| Segurança | Spring Security |
| Autenticação | JWT HS256 (Spring Security Resource Server) |
| Build | Maven (Maven Wrapper incluído) |
| Containerização | Docker multi-stage + Docker Compose |
| Produtividade | Lombok, Spring Boot DevTools, Actuator (Gateway) |

## Estrutura do projeto

```text
GerenciadorDeTarefas/
├── ApiGateway/                 # API Gateway (porta 8080)
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
├── UserService/                # Microsserviço de usuários (porta 8081)
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
├── TaskService/                # Microsserviço de tarefas (porta 8082)
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
├── NotificationService/        # Microsserviço de notificações (porta 8083)
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
├── docker/
│   └── dev/
│       ├── Dockerfile          # Imagem Maven + inotify-tools para o modo dev
│       └── dev-run.sh          # Watch de saves -> mvn compile -> DevTools restart
├── docker-compose.yml          # Ambiente de produção (jars empacotados)
├── docker-compose.dev.yml      # Override para desenvolvimento com hot reload
├── Makefile                    # Atalhos: make dev, make logs, make prod, ...
├── .env.example                # Modelo das variáveis de ambiente
├── .dockerignore
├── .gitignore
└── README.md
```

## Serviços e portas

| Serviço | Porta no host | Porta no container | Banco de dados | Porta do banco no host |
| --- | --- | --- | --- | --- |
| `api-gateway` | 8080 | 8080 | — | — |
| `user-service` | 8081 | 8080 | `userdb` | 5433 |
| `task-service` | 8082 | 8080 | `taskdb` | 5434 |
| `notification-service` | 8083 | 8080 | `notificationdb` | 5435 |

Todas as portas podem ser alteradas no arquivo `.env`.

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) 24+
- [Docker Compose](https://docs.docker.com/compose/) v2

Opcional, para executar os serviços fora do Docker:

- Java 25
- Maven 3.9+ (ou use o `mvnw` incluído em cada serviço)

## Configuração

Crie o arquivo `.env` a partir do modelo:

```bash
cp .env.example .env
```

O `.env` é ignorado pelo Git, portanto credenciais locais não são versionadas. Ajuste as variáveis conforme necessário (veja a [tabela completa](#variáveis-de-ambiente)).

## Como executar

### Ambiente de produção (jars empacotados)

Na raiz do projeto:

```bash
docker compose up -d --build
```

Verifique o status dos containers:

```bash
docker compose ps
```

Acompanhe os logs:

```bash
docker compose logs -f
# ou um serviço específico
docker compose logs -f user-service
```

Para parar os serviços:

```bash
docker compose down
```

Para parar e **remover também os dados** dos bancos:

```bash
docker compose down -v
```

### Build das imagens

Cada microsserviço possui um `Dockerfile` multi-stage:

1. **Build:** imagem `maven:3.10.0-eclipse-temurin-25-noble` compila o projeto e gera o jar.
2. **Runtime:** imagem `eclipse-temurin:25-jre-noble` executa somente o jar.

As imagens rodam com o usuário `appuser` (sem privilégios) e aproveitam o cache de dependências do Maven.

## Desenvolvimento com hot reload

O arquivo `docker-compose.dev.yml` sobrescreve os serviços para usar o código do host via bind mount. Cada container roda `docker/dev/dev-run.sh`, que:

1. compila o projeto na subida;
2. monitora `src/` e `pom.xml` com `inotifywait`;
3. a cada save roda `mvn compile` (atualizando `target/classes`);
4. o Spring Boot DevTools detecta a mudança no classpath e reinicia **apenas o contexto da aplicação**.

Ou seja: **salve o `.java` no editor e a API já reflete a alteração**, sem `docker compose up` e sem depender da IDE compilar.

```bash
make dev          # ou: docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

Acompanhe o hot reload pelos logs:

```bash
make logs-service SERVICE=user-service
# [hotreload] alteração detectada — recompilando workspace...
# [hotreload] compilação OK — o Spring DevTools vai reiniciar a aplicação
```

O código-fonte de cada serviço é montado em `/workspace` e as dependências do Maven ficam no volume `maven-cache`. Para forçar uma compilação manualmente:

```bash
make compile SERVICE=user-service
```

### Atalhos com Makefile

Na raiz do projeto, `make help` lista todos os comandos. Os principais:

```bash
make dev          # sobe tudo com hot reload
make logs         # logs de todos os serviços
make ps           # status dos containers
make ping         # testa GET /user/ping pelo API Gateway
make dev-down     # para o stack (mantém os dados dos bancos)
make prod         # volta para jars de produção (sem hot reload)
```

> No modo de desenvolvimento, os containers usam o UID/GID do usuário local (`UID` e `GID` no `.env`) para evitar arquivos criados como `root` na pasta `target/`.

## Testando os serviços

O `UserService` expõe um endpoint público de verificação. Acesse pelo API Gateway (ponto de entrada único):

```bash
curl http://localhost:8080/user/ping
# resposta: pong
```

O mesmo endpoint também pode ser testado diretamente no serviço:

```bash
curl http://localhost:8081/user/ping
```

Os demais endpoints de negócio ainda serão implementados. Requisições para `/task/**` e `/notification/**` já são encaminhadas aos respectivos serviços e exigem um token JWT válido.

## Autenticação JWT

O fluxo é stateless e descentralizado:

1. O `UserService` cadastra o usuário com a senha protegida por **BCrypt**.
2. No login, o `UserService` assina um token **HS256** com o segredo compartilhado `JWT_SECRET`.
3. O API Gateway valida o token antes de encaminhar a requisição.
4. Cada microsserviço valida o token novamente (defesa em profundidade) e extrai as authorities da claim `roles`.
5. O token vai no header `Authorization: Bearer <token>`.

Claims emitidas: `sub` (username), `userId`, `roles`, `iss` (`user-service`), `iat` e `exp`.

| Método | Rota | Acesso |
| --- | --- | --- |
| `POST` | `/auth/register` | Público |
| `POST` | `/auth/login` | Público |
| `GET` | `/user/ping` | Público |
| `GET` | `/user/me` | Requer JWT |
| `GET` | `/task/ping` | Requer JWT |
| `GET` | `/notification/ping` | Requer JWT |

### Passo a passo

**1. Registre um usuário** (a resposta já traz um token):

```bash
curl -X POST http://localhost:8080/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"senha123"}'
```

```json
{
  "accessToken": "eyJraWQiOiJ...",
  "tokenType": "Bearer",
  "expiresIn": 3600
}
```

**2. Faça login e guarde o token em uma variável** (requer `jq`):

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"senha123"}' | jq -r .accessToken)
```

**3. Acesse um endpoint protegido:**

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/user/me
# {"username":"alice","userId":1,"roles":["ROLE_USER"]}

curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/task/ping
# pong task

curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/notification/ping
# pong notification
```

**4. Confirme que sem token o acesso é negado:**

```bash
curl -i http://localhost:8080/task/ping
# HTTP/1.1 401
```

Os mesmos testes podem ser feitos diretamente nos serviços (`:8081`, `:8082` e `:8083`), pois todos validam o JWT de forma independente do gateway.

## Variáveis de ambiente

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `POSTGRES_USER` | `postgres` | Usuário dos bancos PostgreSQL |
| `POSTGRES_PASSWORD` | `postgres` | Senha dos bancos PostgreSQL |
| `JWT_SECRET` | `dev-secret-key-with-at-least-32-characters-change-me` | Segredo HMAC compartilhado (mínimo 32 caracteres) |
| `JWT_EXPIRATION_MINUTES` | `60` | Validade do token em minutos |
| `JWT_ISSUER` | `user-service` | Emissor esperado na claim `iss` |
| `UID` | `1000` | UID do usuário local (modo dev) |
| `GID` | `1000` | GID do usuário local (modo dev) |
| `GATEWAY_PORT` | `8080` | Porta do API Gateway no host |
| `USER_SERVICE_PORT` | `8081` | Porta do UserService no host |
| `TASK_SERVICE_PORT` | `8082` | Porta do TaskService no host |
| `NOTIFICATION_SERVICE_PORT` | `8083` | Porta do NotificationService no host |
| `USER_SERVICE_URI` | `http://user-service:8080` | URI interna do UserService usada pelo gateway |
| `TASK_SERVICE_URI` | `http://task-service:8080` | URI interna do TaskService usada pelo gateway |
| `NOTIFICATION_SERVICE_URI` | `http://notification-service:8080` | URI interna do NotificationService usada pelo gateway |
| `USER_DB_PORT` | `5433` | Porta do banco `userdb` no host |
| `TASK_DB_PORT` | `5434` | Porta do banco `taskdb` no host |
| `NOTIFICATION_DB_PORT` | `5435` | Porta do banco `notificationdb` no host |

As configurações de conexão dos serviços são injetadas pelo `docker-compose.yml` por meio de variáveis do Spring (`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`).

## Decisões de arquitetura

- **Banco de dados por serviço:** isolamento de dados entre os microsserviços, cada um com seu próprio PostgreSQL e volume Docker.
- **Comunicação via rede Docker:** todos os serviços compartilham a rede bridge `gerenciador-net` e se referenciam pelo nome do serviço (ex.: `user-db:5432`).
- **Healthchecks nos bancos:** os microsserviços só iniciam após o banco correspondente estar saudável (`depends_on` com `condition: service_healthy`).
- **Hibernate `ddl-auto=update`:** usado no ambiente atual para criar/atualizar o schema automaticamente. Para produção, o recomendado é adotar migrations versionadas (Flyway ou Liquibase).
- **Multi-stage build:** imagem final enxuta com apenas o JRE e execução como usuário sem privilégios.
- **JWT descentralizado:** o `UserService` emite os tokens e todos os serviços os validam localmente com o segredo compartilhado, sem estado de sessão.
- **Senhas com BCrypt:** as senhas nunca são armazenadas em texto puro.
- **Persistência:** os dados dos bancos ficam nos volumes nomeados `user-db-data`, `task-db-data` e `notification-db-data`.

## Segurança

- Apenas `/auth/**`, `/user/ping` e `/actuator/health` são públicos; as demais rotas exigem um JWT válido.
- Os serviços são stateless: nenhuma sessão HTTP é criada (`SessionCreationPolicy.STATELESS`) e CSRF está desabilitado por se tratar de uma API REST.
- As senhas são armazenadas com hash BCrypt.
- O `JWT_SECRET` padrão é apenas para desenvolvimento. **Defina um segredo forte e exclusivo no `.env` antes de qualquer uso real.**
- Para produção, considere evoluir de HS256 para RSA/EC com JWKS ou um Authorization Server dedicado (ex.: Spring Authorization Server/Keycloak), permitindo rotação de chaves.
- As credenciais padrão (`postgres`/`postgres`) são apenas para desenvolvimento. **Altere-as no `.env` antes de qualquer uso real.**
- O `.env` não é versionado; apenas o `.env.example` é mantido no repositório.

## Roadmap

- [x] Estrutura inicial dos quatro microsserviços
- [x] Dockerfiles multi-stage com execução como usuário não-root
- [x] Docker Compose para produção e desenvolvimento (hot reload)
- [x] Um banco PostgreSQL isolado por serviço
- [x] Endpoint público `/user/ping` no `UserService`
- [x] Configuração das rotas no API Gateway
- [ ] CRUD de usuários, tarefas e notificações
- [x] Autenticação e autorização com JWT
- [ ] Migrations de banco com Flyway ou Liquibase
- [ ] Testes de integração entre os serviços
- [ ] CI/CD e publicação das imagens

## Licença

Este projeto ainda não possui uma licença definida.
