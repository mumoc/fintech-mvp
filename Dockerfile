# Development image for the Bravo Fintech API.
# Gems are installed at runtime into a named volume (see docker-compose.yml) so
# that a Gemfile change does not require an image rebuild.
FROM ruby:3.3.6-slim

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    RAILS_ENV=development

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        postgresql-client \
        git \
        curl \
        libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 2.5.6

WORKDIR /app

# The application source is bind-mounted at runtime (docker-compose.yml), so we
# only declare the entrypoint/command here. The entrypoint installs gems.
ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
