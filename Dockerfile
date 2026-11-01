FROM alpine:3.20

RUN apk add --no-cache curl bash jq bind-tools

LABEL maintainer="M.A.R. Mechatronics & Autonomous Robotics Team"
LABEL description="M.A.R. Zero-Trust Ingress & Authelia SSO Management Container"

WORKDIR /app
COPY authelia/ /app/authelia/
COPY caddy/ /app/caddy/
COPY k8s/ /app/k8s/

CMD ["sh", "-c", "echo 'M.A.R. Auth Proxy Config Container' && sleep infinity"]
