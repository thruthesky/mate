FROM node:24-bookworm-slim
ARG CODEX_VERSION=0.159.2
RUN apt-get update && apt-get install -y --no-install-recommends git python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @openai/codex@${CODEX_VERSION}
COPY run.mjs /opt/agent/run.mjs
COPY sample /opt/agent/sample
ENV CODEX_HOME=/session/codex HOME=/home/node
WORKDIR /workspace
USER node
CMD ["sleep", "infinity"]
