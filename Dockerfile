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
RUN /etc/pki/tls/certs/make-dummy-cert /etc/ssl/certs/nginx.crt /etc/ssl/certs/nginx.key /etc/nginx/dhparam.pem

FROM nginx:stable-alpine as final
RUN apk add --no-cache nodejs openssl

COPY bin/ /usr/share/nginx/html/bin
COPY config/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src /usr/share/nginx/html/src
COPY --from=build /etc/ssl/certs /etc/ssl/certs
COPY --from=build /etc/nginx/dhparam.pem /etc/nginx/dhparam.pem

EXPOSE 80 3000
USER nginx
WORKDIR /usr/share/nginx/html
CMD ["sh", "-c", "nginx -g 'daemon off;'; node src/000.js"]
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1