# Stage 1: Build Stage
FROM node:22-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
COPY src src
RUN npm install --omit-dev
RUN npm run build

# Stage 2: Runtime Stage
FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/node_modules ./node_modules
CMD [ "dist/server.js" ]