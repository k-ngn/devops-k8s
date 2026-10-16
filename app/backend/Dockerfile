FROM node:20-alpine

WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm ci --only=production

# Bundle app source
COPY server.js ./

EXPOSE 4000
USER node

CMD ["node", "server.js"]
