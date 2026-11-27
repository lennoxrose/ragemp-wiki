# Built and pushed to ghcr.io by .github/workflows/image.yml. Manual build from the repo root:  docker build -f configs/docker/Dockerfile -t <image> .
FROM golang:1.27 AS wikisync
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -o /out/wikisync ./cmd/wikisync

FROM ruby:3.4-slim AS build
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libmariadb-dev pkg-config git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test"
COPY web/Gemfile web/Gemfile.lock ./
RUN bundle install && rm -rf "$BUNDLE_PATH"/ruby/*/cache
COPY web/ .
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

FROM ruby:3.4-slim
# chromium is what wikisync drives to get past Cloudflare.
RUN apt-get update -qq && apt-get install -y --no-install-recommends libmariadb3 chromium fonts-liberation && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development:test" \
    WIKI_ROOT=/data/dist WIKISYNC_BIN=/usr/local/bin/wikisync CHROMIUM_PATH=/usr/bin/chromium CHROMIUM_NO_SANDBOX=1 \
    RAILS_LOG_TO_STDOUT=1
COPY --from=wikisync /out/wikisync /usr/local/bin/wikisync
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN useradd -u 1000 -m rails && mkdir -p /data/dist && chown -R rails /app/log /app/tmp /app/storage /data
USER 1000
EXPOSE 3000
# `rails server` (not bare puma) so the in-process sync scheduler starts.
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
