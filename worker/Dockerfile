FROM docker:29-cli AS docker
FROM node:24-bookworm-slim
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker
WORKDIR /app
COPY package.json /app/
COPY src /app/src
CMD ["node", "src/worker.ts"]
