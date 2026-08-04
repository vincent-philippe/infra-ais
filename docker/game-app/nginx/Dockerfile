FROM nginx:1.27-alpine

RUN apk add --no-cache wget \
 && wget -q -O /usr/local/bin/gosu \
    "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true

# Create dedicated non-root user
RUN addgroup -g 1001 nginxgroup \
 && adduser -u 1001 -G nginxgroup -s /bin/sh -D nginxuser

# Allow nginxuser to write nginx runtime files
# Remove symlinks from base image (point to /dev/stdout|stderr, not chown-able)
# and create plain files owned by nginxuser instead
RUN mkdir -p /var/cache/nginx /var/log/nginx \
 && rm -f /var/log/nginx/access.log /var/log/nginx/error.log \
 && touch /var/log/nginx/access.log /var/log/nginx/error.log \
 && chown -R nginxuser:nginxgroup /var/cache/nginx /var/log/nginx

COPY nginx.conf /etc/nginx/nginx.conf
RUN chown nginxuser:nginxgroup /etc/nginx/nginx.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
