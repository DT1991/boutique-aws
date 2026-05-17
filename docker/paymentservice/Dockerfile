# Patched Dockerfile for paymentservice.
# Upstream src/paymentservice/Dockerfile uses `apk add nodejs` in the final stage,
# which installs the latest Node.js from Alpine repos (currently v24) — incompatible
# with pprof native bindings compiled against Node 20 in the builder stage.
# Fix: use the same node:20 image in both stages to guarantee ABI compatibility.
# Keep src/ untouched so upstream merges stay clean.

ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM node:20.20.2-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293 AS builder

RUN apk add --update --no-cache \
    python3 \
    make \
    g++

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --only=production

FROM node:20.20.2-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app/node_modules ./node_modules

COPY . .

EXPOSE 50051

ENTRYPOINT [ "node", "index.js" ]
