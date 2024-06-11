# Use the official Python 3.9 image from the Docker Hub
FROM python:3.9

# Set the default shell to bash and the working directory in the container
SHELL ["/bin/bash", "-ci"]
WORKDIR /hdp

# Install Rust using Rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    echo 'export PATH="/root/.cargo/bin:$PATH"' >> /root/.bashrc

# Add Cargo executables to PATH
RUN mkdir -p /root/.local/bin && \
    echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc

# Install cairo1-run into PATH
RUN git clone https://github.com/HerodotusDev/cairo-vm.git && \
    cd cairo-vm && git checkout aecbb3f01dacb6d3f90256c808466c2c37606252 && \
    cd cairo1-run && cargo install --path .

# Copy project requirements and install them
COPY tools/make/requirements.txt tools/make/requirements.txt
RUN pip install -r tools/make/requirements.txt

# Copy and install Contract bootloader SNOS dependencies
COPY packages/cairo-lang-0.13.1.zip packages/cairo-lang-0.13.1.zip
RUN pip install packages/cairo-lang-0.13.1.zip

# Copy the entire project into the image
COPY . .

# Install Python package modules
RUN pip install .

# Set the default command to execute
# CMD ["bash", "-c", "source /root/.bashrc && python tools/make/launch_cairo_files.py -run_hdp"]
