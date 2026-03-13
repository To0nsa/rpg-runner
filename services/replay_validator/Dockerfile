FROM dart:3.10.4 AS build

WORKDIR /workspace

# Copy package dependencies first to maximize docker cache reuse.
COPY packages/runner_core /workspace/packages/runner_core
COPY packages/run_protocol /workspace/packages/run_protocol
COPY services/replay_validator /workspace/services/replay_validator

WORKDIR /workspace/services/replay_validator
RUN dart pub get
RUN mkdir -p /workspace/out
RUN dart compile exe bin/server.dart -o /workspace/out/replay_validator_server

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/out/replay_validator_server /server

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/server"]
