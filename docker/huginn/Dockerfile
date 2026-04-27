FROM ghcr.io/huginn/huginn:latest

# The current official image can start without the PostgreSQL gem installed.
# Re-running bundle install during the image build materializes the locked gems,
# including pg, so the container can boot against PostgreSQL.
RUN printf '%s\n' \
    'APP_SECRET_TOKEN=build-only-secret' \
    'DATABASE_ADAPTER=postgresql' \
    'DATABASE_NAME=huginn' \
    'DATABASE_USERNAME=huginn' \
    'DATABASE_PASSWORD=huginn' \
    'DATABASE_HOST=postgres' \
    'DATABASE_PORT=5432' \
    > .env \
    && bundle install \
    && rm .env
