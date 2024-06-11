FROM hdp-cairo:latest

# Set the default shell to bash and the working directory in the container
SHELL ["/bin/bash", "-ci"]
WORKDIR /hdp

# Update package lists and install GNU Parallel
RUN apt-get update && \
    apt-get install -y parallel

# Install scarb
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Download testing fixtures
RUN git clone https://github.com/HerodotusDev/hdp-test

# Set the default command to execute
CMD ["bash", "-c", "source /root/.bashrc && ./tools/make/full_flow_test.sh"]
