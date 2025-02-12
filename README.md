# dockerized-service-deployment

# Goal

The goal of this project is to dockerize a simple Node.js service and deploy it to a remote server using GitHub Actions.

# Dockerfile

I have choosen two step build with distroless image as a runtime

### What is a distroless image and why should we use it?

Distroless images are designed to be minimal, containing only essentails to run an application. They are stripped of unnecessary software like package managers, utilities and shells. That makes them more secure and less prone to vulnerabilities.

Google provides distroless images for various programming languages like Python, Java, Go and in this case Node.js

- [Documentation for gcr.io/distroless/nodejs](https://github.com/GoogleContainerTools/distroless/tree/main/nodejs)
- [Google example how to use it](https://github.com/GoogleContainerTools/distroless/blob/main/examples/nodejs/Dockerfile)

### Building a Node.js Application with a Distroless Image

```Dockerfile
# Stage 1: Build Stage
FROM node:22-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
COPY src src
RUN npm install --omit-dev
RUN npm run build
```

In this step, dependencies are installed, and the Node.js application is built. We use a full Node.js image because it includes the necessary tools for building the package - these tools are missing in the distroless image. Therefore, when using distroless images, a multi-stage build is mandatory.

```Dockerfile
# Stage 2: Runtime Stage
FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/node_modules ./node_modules
CMD [ "dist/server.js" ]
```

This step copies only the compiled application code and necessary dependencies, ensuring a minimal and secure runtime environment. By excluding build tools that are not needed at runtime, we reduce the attack surface and minimize potential vulnerabilities.

**IMPORTANT**: As stated in the documentation the entry point to the image is set to "node" this means you only need to specify a path to a `.js` file in the `CMD`

The image is also slightly smaller, compared to `node:22-alpine`, the `distroless/nodejs22-debian12` is 14MB lighter:

```
REPOSITORY          TAG       IMAGE ID        CREATED               SIZE
hello-world-app2    latest    b5474cc4622a    About a minute ago    184MB
hello-world-app     latest    6666f19403e0    9 minutes ago         170MB
```

We can verify that it is not possible to connect to the container using `sh` or `bash`:

```console
$ docker exec -it a145c5d3884a sh
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH: unknown
$ docker exec -it a145c5d3884a bash
OCI runtime exec failed: exec failed: unable to start container process: exec: "bash": executable file not found in $PATH: unknown
```

Even running the node fails

```console
$ docker exec -it a145c5d3884a node -v
OCI runtime exec failed: exec failed: unable to start container process: exec: "node": executable file not found in $PATH: unknown
```
