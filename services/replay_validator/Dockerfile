FROM dart:3.13.1@sha256:85016bdd10a5799c8f0f4d5bf2b150b46a0db548cc484b4ce87669a53754d6f5 AS build

WORKDIR /workspace

# Copy package dependencies first to maximize docker cache reuse.
COPY packages/runner_core /workspace/packages/runner_core
COPY packages/run_protocol /workspace/packages/run_protocol
COPY services/replay_validator /workspace/services/replay_validator

WORKDIR /workspace/services/replay_validator
RUN dart pub get
RUN mkdir -p /workspace/out
RUN dart compile exe bin/server.dart -o /workspace/out/replay_validator_server

FROM gcr.io/distroless/base-nossl-debian12:nonroot@sha256:363001a3ceb82130280f924fb8dd9540861aba152a87974a205bc7aa7062ad99

COPY --from=build --chown=65532:65532 /workspace/out/replay_validator_server /server

ENV PORT=8080
EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/server"]
