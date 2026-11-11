#!/bin/sh
set -e

# Database setup logic
DB_ENGINE=${DATABASE_ENGINE:-sqlite3}

if [ "$DB_ENGINE" = "postgresql" ]; then
  echo "Using PostgreSQL database."
  echo "Database: ${DATABASE_NAME:-fopcam}@${DATABASE_HOST:-localhost}:${DATABASE_PORT:-5432}"
elif [ -f /app/db.sqlite3 ]; then
  echo "Using existing SQLite database."
else
  echo "No database file found, creating a fresh SQLite database."
fi

python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear

exec uvicorn fopcam.asgi:application --host 0.0.0.0 --port 8000
