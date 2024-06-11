FROM python:3.9

# Set the default shell to bash
SHELL ["/bin/bash", "-ci"]

# Set the working directory in the container
WORKDIR /hdp

# Install Rust using Rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    echo 'export PATH="/root/.cargo/bin:$PATH"' >> /root/.bashrc

# Add Cargo executables to PATH
RUN mkdir -p /root/.local/bin && \
    echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc

# Install cairo1-run into PATH
RUN git clone https://github.com/HerodotusDev/cairo-vm.git \
    && cd cairo-vm && git checkout aecbb3f01dacb6d3f90256c808466c2c37606252 \
    && cd cairo1-run && cargo install --path .

# Copy project into image
COPY . .

# Install project requirements
RUN pip install -r tools/make/requirements.txt

# Install Contract bootloader SNOS dependencies
RUN pip install packages/cairo-lang-0.13.1.zip

# Install python packages modules
RUN pip install .

CMD ["python","tools/make/launch_cairo_files.py","-run_hdp"]