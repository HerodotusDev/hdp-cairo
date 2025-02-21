# Use the official Python 3.9 image from the Docker Hub
FROM python:3.9

# Set the default shell to bash and the working directory in the container
SHELL ["/bin/bash", "-c"]
WORKDIR /hdp-cairo

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Rust using rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy the project files into the container
COPY packages/cairo-lang-0.13.1.zip packages/cairo-lang-0.13.1.zip

# Set up Python virtual environment and install dependencies
RUN python -m venv venv && \
    source venv/bin/activate && \
    pip install --upgrade pip && \
    pip install packages/cairo-lang-0.13.1.zip

# Copy the project files into the container
COPY . .

# Install specific Rust binaries
RUN cargo install --path ./crates/cli

ENTRYPOINT ["hdp-cli"]
CMD ["program-hash"]