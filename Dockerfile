FROM rust:slim

# Install uv, the Python package manager.
COPY --from=ghcr.io/astral-sh/uv:0.8.13 /uv /uvx /bin/

# Set the working directory for all subsequent commands.
WORKDIR /hdp-cairo

# Copy dependency files FIRST to leverage Docker's layer caching.
# If these files don't change, Docker won't re-run the `uv sync` step.
COPY pyproject.toml uv.lock ./
COPY packages/cairo-lang-0.13.3.zip ./packages/cairo-lang-0.13.3.zip

# Synchronize and install project dependencies using uv.
RUN uv sync

# Copy the rest of the application source code into the container.
COPY . .

# Install the specific Rust binary from the local crate.
# We use the `--locked` flag to ensure the build uses the exact versions
# specified in Cargo.lock, for reproducibility.
RUN cargo install --path ./crates/cli --locked

# Set the default executable for the container.
ENTRYPOINT ["/hdp-cairo/target/release/hdp-cli"]

# Set the default command when the container is run without any arguments.
# This provides a default action for the entrypoint.
CMD ["program-hash"]