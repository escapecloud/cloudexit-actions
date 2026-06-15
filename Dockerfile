FROM python:3.14-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /action
COPY entrypoint.sh /action/entrypoint.sh

ENTRYPOINT ["bash", "/action/entrypoint.sh"]
