# Use the official Python 3.9 image from the Docker Hub
FROM python:3.9.0

# Set the default shell to bash and the working directory in the container
SHELL ["/bin/bash", "-ci"]
WORKDIR /hdp-cairo

# Copy project requirements and install them
COPY tools/make/requirements.txt tools/make/requirements.txt
RUN python -m pip install --upgrade pip && pip install -r tools/make/requirements.txt

# Copy and install Contract bootloader SNOS dependencies
COPY packages/cairo-lang-0.13.1.zip packages/cairo-lang-0.13.1.zip
RUN pip install packages/cairo-lang-0.13.1.zip

# Copy the entire project into the image
COPY . .

# Install Python package modules
RUN pip install .

# Compile the HDP
RUN cairo-compile --cairo_path="packages/eth_essentials" "src/hdp.cairo" --output "build/hdp.json"
RUN cairo-compile --cairo_path="packages/eth_essentials" "src/contract_dry_run.cairo" --output "build/contract_dry_run.json"

# Export HDP Program Hash
RUN cairo-hash-program --program build/hdp.json >> build/program_hash.txt
