FROM node:lts-alpine as build
WORKDIR /src
COPY package*.json ./
COPY src/ .
RUN npm install -g npm \
    && npm install . \
    && npm prune --omit=dev --omit=optional \
    && npm cache clean --force

FROM nginx:stable-alpine as final
RUN apk add --no-cache nodejs

COPY --from=build /src /usr/share/nginx/html/src
COPY bin/ /usr/share/nginx/html/bin
COPY config/nginx.conf /etc/nginx/conf.d/default.conf

HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
WORKDIR /usr/share/nginx/html
USER nginx

EXPOSE 80 3000
CMD ["sh", "-c", "node src/000.js && nginx -g 'daemon off;'"]