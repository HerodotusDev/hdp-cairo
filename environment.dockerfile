# Use the official Python 3.9 image from the Docker Hub
FROM python:3.10

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
