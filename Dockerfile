FROM node:lts-alpine as build
RUN apk add --no-cache openssl
WORKDIR /src
# certs
COPY config/make-dummy-cert.sh ./config/
RUN chmod +x ./config/make-dummy-cert.sh
RUN ./config/make-dummy-cert.sh ./config/nginx.key ./config/nginx.crt ./config/dhparam.pem
# nginx.conf
COPY config/ ./config/

COPY bin/ ./bin
COPY package*.json .
COPY src/ .

RUN npm install -g npm \
    && npm install . \
    && npm prune --omit=dev --omit=optional \
    && npm cache clean --force

### Run in nginx container
FROM nginx:stable-alpine as final
RUN apk add --no-cache openssl nodejs
WORKDIR /src

COPY --from=build /src .
COPY --from=build /src/config/ /etc/nginx/

RUN nginx -t
RUN chown -R nginx .
USER nginx
EXPOSE 80 443 3000
CMD ["/bin/sh", "-c", "nginx; node 000.js"]
HEALTHCHECK CMD wget --quiet --tries=1 --spider https://localhost/health || exit 1