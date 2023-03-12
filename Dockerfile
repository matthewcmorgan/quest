FROM node:16-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install . --omit=dev

COPY src/ .

# Add a healthcheck
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

EXPOSE 3000

CMD [ "npm", "start" ]