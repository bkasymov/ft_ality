FROM debian:stable

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        ocaml \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["bash"]
