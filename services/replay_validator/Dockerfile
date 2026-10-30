ARG NAVIGATION_CACHE_IMAGE=navigation-empty

FROM gcr.io/distroless/base-nossl-debian12:nonroot@sha256:363001a3ceb82130280f924fb8dd9540861aba152a87974a205bc7aa7062ad99 AS runtime

FROM dart:3.13.1@sha256:85016bdd10a5799c8f0f4d5bf2b150b46a0db548cc484b4ce87669a53754d6f5 AS sdk

# Bootstrap has no previous pack. Ordinary releases select a verified immutable
# image instead; the producer below validates every reused key and graph digest.
FROM sdk AS navigation-empty
RUN mkdir -p /navigation

FROM ${NAVIGATION_CACHE_IMAGE} AS navigation-cache

FROM sdk AS build

WORKDIR /workspace

# Copy package dependencies first to maximize docker cache reuse.
COPY packages/runner_core /workspace/packages/runner_core
COPY packages/run_protocol /workspace/packages/run_protocol
COPY services/replay_validator /workspace/services/replay_validator
COPY functions/src/runs/navigation_routes.json /workspace/functions/src/runs/navigation_routes.json

WORKDIR /workspace/services/replay_validator
RUN dart pub get --enforce-lockfile
RUN dart --packages=.dart_tool/package_config.json ../../packages/runner_core/tool/update_navigation_revision.dart --check
RUN mkdir -p /workspace/out
RUN dart compile exe bin/server.dart -o /workspace/out/replay_validator_server
RUN dart compile exe --packages=.dart_tool/package_config.json ../../packages/runner_core/tool/prepare_navigation.dart -o /workspace/out/prepare_navigation
COPY --from=navigation-cache /navigation /workspace/out/navigation
RUN /workspace/out/prepare_navigation --plan=/workspace/functions/src/runs/navigation_routes.json --output=/workspace/out/navigation

FROM runtime

COPY --from=build --chown=65532:65532 /workspace/out/replay_validator_server /server
COPY --from=build --chown=65532:65532 /workspace/out/navigation /navigation

ENV PORT=8080
EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/server"]
