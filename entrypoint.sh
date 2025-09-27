#!/bin/bash
set -e

cd /app/backend
bundle exec rails db:create db:migrate

exec "$@"

