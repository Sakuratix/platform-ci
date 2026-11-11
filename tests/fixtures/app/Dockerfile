FROM python:3.12-slim
# hadolint ignore=DL3005
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN useradd --uid 10001 --no-create-home app
WORKDIR /app
COPY server.py .
USER 10001
EXPOSE 8080
ENTRYPOINT ["python", "server.py"]
