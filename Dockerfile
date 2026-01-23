FROM rust:1.89.0 AS builder

# Install uv, the Python package manager.
COPY --from=ghcr.io/astral-sh/uv:0.8.13 /uv /uvx /bin/

# Set the working directory for all subsequent commands.
WORKDIR /hdp-cairo

# Install the pinned nightly toolchain.
RUN rustup toolchain install nightly-2025-04-06 && rustup default nightly-2025-04-06

# Copy dependency files FIRST to leverage Docker's layer caching.
# If these files don't change, Docker won't re-run the `uv sync` step.
COPY pyproject.toml uv.lock ./
COPY packages/cairo-lang-0.13.3.zip ./packages/cairo-lang-0.13.3.zip

# Synchronize and install project dependencies using uv.
RUN uv sync

# Pre-fetch Rust dependencies using workspace sources.
COPY Cargo.toml Cargo.lock ./
COPY crates/ ./crates/
COPY tests/ ./tests/
COPY packages/eth_essentials/cairo_vm_hints/ ./packages/eth_essentials/cairo_vm_hints/
RUN cargo fetch

# Copy the rest of the application source code into the container.
COPY . .

# Precompile Cairo artifacts and set stable paths for the binary.
ENV HDP_COMPILED_JSON=/opt/hdp/compiled.json
ENV DRY_RUN_COMPILED_JSON=/opt/hdp/dry_run_compiled.json
RUN mkdir -p /opt/hdp && \
    .venv/bin/cairo-compile --cairo_path=/hdp-cairo:/hdp-cairo/packages/eth_essentials /hdp-cairo/src/hdp.cairo \
      --output "$HDP_COMPILED_JSON" --proof_mode && \
    .venv/bin/cairo-compile --cairo_path=/hdp-cairo:/hdp-cairo/packages/eth_essentials \
      /hdp-cairo/src/contract_bootloader/contract_dry_run.cairo --output "$DRY_RUN_COMPILED_JSON"

# Install the specific Rust binary from the local crate.
# We use the `--locked` flag to ensure the build uses the exact versions
# specified in Cargo.lock, for reproducibility.
RUN cargo install --path ./crates/cli --locked

FROM debian:bookworm-slim

RUN useradd --create-home --uid 10001 hdp && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/cargo/bin/hdp-cli /usr/local/bin/hdp-cli
COPY --from=builder /opt/hdp /opt/hdp

USER hdp

# Set the default executable for the container.
ENTRYPOINT ["hdp-cli"]

# Set the default command when the container is run without any arguments.
# This provides a default action for the entrypoint.
CMD ["program-hash"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["hdp-cli", "--version"]