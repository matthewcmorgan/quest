FROM node:lts-alpine
RUN mkdir -p /src
WORKDIR /src
COPY package*.json ./
COPY src/ ./src
COPY bin/ ./bin

RUN npm install -g npm \
    && npm install . \
    && npm prune --omit=dev --omit=optional \
    && npm cache clean --force

EXPOSE 3000
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
CMD ["sh", "-c", "node ./000.js"]