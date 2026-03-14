# ── Stage 1: builder ──────────────────────────────────────────────
FROM node:22-bookworm-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev && \
    npm install --no-save thepopebot@$(node -p "require('./package.json').version")

# ── Stage 2: runtime ─────────────────────────────────────────────
FROM node:22-bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git ca-certificates && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g pm2

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

COPY templates/docker/event-handler/ecosystem.config.cjs /opt/ecosystem.config.cjs

EXPOSE 80
CMD ["pm2-runtime", "/opt/ecosystem.config.cjs"]
