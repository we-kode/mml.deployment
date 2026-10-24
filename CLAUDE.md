# Deployment

## Purpose

Container orchestration and configuration templates for the complete MML backend. This project runs PostgreSQL, Redis, RabbitMQ, Identity, Media, and an Nginx TLS reverse proxy on the external `wekode.mml` network.

## Code map

- `docker-compose.yml` defines service images, dependencies, networks, volumes, and logging.
- `db/` contains PostgreSQL configuration and initialization templates.
- `cache/` contains Redis configuration.
- `mbus/` contains RabbitMQ configuration and plugins.
- `reverse-proxy/` contains Nginx templates and TLS routing configuration.

## Local validation

```bash
docker compose --env-file <env-file> config
docker compose --env-file <env-file> up -d
```

Use a secret-bearing environment file outside version control. Verify certificate paths, volume ownership, service image versions, and the external network before starting. Do not place passwords, signing/encryption secrets, private keys, or host-specific paths in tracked templates.

Deployment changes are operational API changes. Update `mml.project/docs/setup/backend.mdx` or the appropriate setup page whenever service names, ports, variables, volumes, TLS, or startup behavior changes.
