FROM node:22-alpine AS build

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

# ---- runtime ----
FROM node:22-alpine

RUN apk add --no-cache wget \
 && wget -q -O /usr/local/bin/gosu \
    "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true

# Create dedicated non-root user
RUN addgroup -g 1001 appgroup \
 && adduser -u 1001 -G appgroup -s /bin/sh -D appuser

WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY src/ ./src/

RUN chown -R appuser:appgroup /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "src/server.js"]
