FROM node:lts-alpine as build
WORKDIR /src
COPY package*.json ./
COPY src/ .
RUN apk add --no-cache openssl

RUN npm install -g npm \
    && npm install . \
    && npm prune --omit=dev --omit=optional \
    && npm cache clean --force
COPY config/make_dummy_cert.sh /etc/pki/tls/certs/make-dummy-cert
RUN chmod +x /etc/pki/tls/certs/make-dummy-cert

FROM nginx:stable-alpine as final
RUN apk add --no-cache nodejs openssl

COPY --from=build /src /usr/share/nginx/html/src
COPY --from=build /etc/pki/tls/certs/make-dummy-cert /etc/pki/tls/certs/make-dummy-cert
COPY bin/ /usr/share/nginx/html/bin
RUN /etc/pki/tls/certs/make-dummy-cert /etc/ssl/certs/nginx.crt /etc/ssl/certs/nginx.key /etc/nginx/dhparam.pem
COPY config/nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
WORKDIR /usr/share/nginx/html

EXPOSE 80 3000
CMD ["sh", "-c", "/etc/pki/tls/certs/make-dummy-cert /etc/ssl/certs/nginx.crt /etc/ssl/certs/nginx.key /etc/nginx/dhparam.pem && node src/000.js && nginx -g 'daemon off;'"]
USER nginx