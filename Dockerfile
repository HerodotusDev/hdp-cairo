# Use the official Python 3.9 image from the Docker Hub
FROM python:3.9-slim

# Set the default shell to bash and the working directory in the container
SHELL ["/bin/bash", "-c"]
WORKDIR /hdp-cairo

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Rust using rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install uv, the Python package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Copy dependency definition files AND the local package before installation
COPY pyproject.toml uv.lock ./
COPY packages/cairo-lang-0.13.3.zip ./packages/cairo-lang-0.13.3.zip

# Set up Python virtual environment and install dependencies using uv
RUN uv sync

# Copy the rest of the project files into the container
COPY . .

# Set path to include venv binaries, so they can be called directly
ENV PATH="/hdp-cairo/.venv/bin:${PATH}"

# Install specific Rust binaries
RUN cargo install --path ./crates/cli

ENTRYPOINT ["hdp-cli"]
CMD ["program-hash"]
