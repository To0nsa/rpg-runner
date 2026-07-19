FROM dart:3.10.4@sha256:e3e80caac67fd6cd94a64e42025a67a747eba5a634055d087c8bd0971b3e12d9 AS build

WORKDIR /workspace

# Copy package dependencies first to maximize docker cache reuse.
COPY packages/runner_core /workspace/packages/runner_core
COPY packages/run_protocol /workspace/packages/run_protocol
COPY services/replay_validator /workspace/services/replay_validator

WORKDIR /workspace/services/replay_validator
RUN dart pub get
RUN mkdir -p /workspace/out
RUN dart compile exe bin/server.dart -o /workspace/out/replay_validator_server

FROM gcr.io/distroless/base-debian12:nonroot@sha256:6c806311d31c11d364a8d13a022af5a48f29e43bd585ad6b51f1bb447f83d239

COPY --from=build --chown=65532:65532 /workspace/out/replay_validator_server /server

ENV PORT=8080
EXPOSE 8080

USER 65532:65532

ENTRYPOINT ["/server"]
