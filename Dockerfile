FROM python:3.9

# Set the working directory in the container
WORKDIR /hdp

COPY . .

RUN pip install -r tools/make/requirements.txt \
    && pip install packages/cairo-lang-0.13.1.zip \
    && pip install .

CMD ["python","tools/make/launch_cairo_files.py","-run_hdp"]