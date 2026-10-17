FROM node:20-alpine

WORKDIR /usr/src/app

# Upgrade OS packages to apply security patches
RUN apk update && apk upgrade --no-cache

# Install app dependencies
COPY package*.json ./
RUN npm ci --only=production

# Bundle app source
COPY server.js ./

EXPOSE 4000
USER node

CMD ["node", "server.js"]
