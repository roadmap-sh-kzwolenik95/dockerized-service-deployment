# dockerized-service-deployment
https://roadmap.sh/projects/dockerized-service-deployment

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

# Build the docker image in GitHub Actions pipeline

We are using DigitalOcean Container Registry, which is great for small projects since the **Starter** tier gives 1 repository and 500MiB of storage for free.

To authenticate with the registry, we use `docker/login-action` and specify the tag `registry.digitalocean.com/roadmapsh/hello-world-app` to push the container.

To enable caching, we first set up Buildx using `docker/setup-buildx-action` which configures the build driver to `docker-container`. This is required for the next step, where we use `docker/build-push-action` to build and push the image. Caching is enabled via GitHub Actions by specifying `type=gha`, which provides up to 10 GB of storage—more than enough for our needs.

```yaml
- name: Login to DigitalOcean Container Registry
  uses: docker/login-action@v3
  with:
    registry: registry.digitalocean.com
    username: ${{ vars.DIGITALOCEAN_USERNAME }}
    password: ${{ secrets.DIGITALOCEAN_API_TOKEN }}

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push Docker images
  uses: docker/build-push-action@v6.13.0
  with:
    context: "hello-world-app"
    push: true
    tags: "registry.digitalocean.com/roadmapsh/hello-world-app"
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## Why Use Caching in GitHub Actions?

When running `docker build` locally, Docker uses its cache to speed up the process and avoid unnecessary work. However, GitHub Actions runners are ephemeral, meaning they do not retain data between runs. Without a remote cache, Docker has to rebuild each layer every time, even if nothing has changed. By enabling remote caching, we significantly reduce build times.

After enabling caching, we can see a build summary in the Actions tab. The table below shows cache utilization and total build duration:

| ID       | Name                | Status       | Cached | Duration |
| -------- | ------------------- | ------------ | ------ | -------- |
| `58G243` | **hello-world-app** | ✅ completed | 44%    | 15s      |

Here’s an example of a build step **before** caching:

```
#13 [builder 5/6] RUN npm install --omit-dev
#13 2.068 npm warn deprecated inflight@1.0.6: This module is not supported, and leaks memory. Do not use it. Check out lru-cache if you want a good and tested way to coalesce async requests by a key value, which is much more comprehensive and powerful.
#13 2.187 npm warn deprecated glob@7.2.3: Glob versions prior to v9 are no longer supported
#13 3.756
#13 3.756 added 339 packages, and audited 340 packages in 4s
#13 3.756
#13 3.756 88 packages are looking for funding
#13 3.756   run `npm fund` for details
#13 3.757
#13 3.757 found 0 vulnerabilities
#13 3.758 npm notice
#13 3.758 npm notice New major version of npm available! 10.9.2 -> 11.1.0
#13 3.758 npm notice Changelog: https://github.com/npm/cli/releases/tag/v11.1.0
#13 3.758 npm notice To update run: npm install -g npm@11.1.0
#13 3.758 npm notice
#13 DONE 4.1s
```

And here’s the same step after caching was configured and populated:

```
#16 [builder 5/6] RUN npm install --omit-dev
#16 CACHED
```

With caching enabled, this step is completely skipped, which also means the cached layers do not need to be rebuilt or pushed to the registry again. This saves both time and bandwidth.

# Passing secrets in the pipeline

To deploy the container, I used the SSH action to connect to the remote Linux server and run the necessary Docker commands.

```yaml
- name: Run the container on remote host
  uses: appleboy/ssh-action@v1.2.0
  with:
    host: ${{ steps.terraform-output.outputs.stdout }}
    username: root
    key: ${{ secrets.SSH_PRIV_KEY }}
    script: |
      docker login --username "${{ vars.DIGITALOCEAN_USERNAME }}" \
        --password "${{ secrets.DIGITALOCEAN_API_TOKEN }}" registry.digitalocean.com
      docker stop hello-world-app-container || true
      docker rm hello-world-app-container || true
      docker run --detach --pull=always \
        --name hello-world-app-container \
        --publish 80:80 \
        -e "SECRET_MESSAGE=${{ secrets.SECRET_MESSAGE }}" \
        -e "USERNAME=${{ vars.USERNAME }}" \
        -e "PASSWORD=${{ secrets.PASSWORD }}" \
        registry.digitalocean.com/roadmapsh/hello-world-app
```

GitHub secrets are injected into commands using the ${{ secrets.<SECRET_NAME> }} syntax.
Remember always quote secret/variable expansions, if a secret contains spaces or special characters, unquoted expansions can lead to hard-to-debug errors. Secrets are masked by \*\*\* in the logs, so they are not exposed:

```
docker login --username "kzwolenik95@gmail.com" --password "***" registry.digitalocean.com
```
