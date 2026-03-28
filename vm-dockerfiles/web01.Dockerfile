# Source priority: helm_bak_20260318(dev-web-nginx) -> dockerfiles/nginx-dockerfile
FROM nginx:1.25-alpine

COPY web01-nginx.conf /etc/nginx/conf.d/default.conf

RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    openssh-client

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
