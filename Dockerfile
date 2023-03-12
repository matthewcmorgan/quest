FROM node:lts-alpine as build
WORKDIR /src
COPY package*.json ./
RUN npm install . \
    && npm prune --omit=dev --omit=optional \
    && npm cache clean --force

COPY src/ .

FROM node:lts-alpine as base
WORKDIR /app
EXPOSE 3000

FROM base as final
WORKDIR /app
COPY --from=build /src /app
CMD [ "npm", "start" ]
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1