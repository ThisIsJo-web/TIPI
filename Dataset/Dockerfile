FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY src/ ./src/
COPY data/ ./data/

EXPOSE 4001

ENV PORT=4001
ENV NODE_ENV=production

CMD ["npm", "start"]
