FROM python:3.11-slim-bookworm

WORKDIR /app

# Gestión de dependencias con pipenv + Pipfile.lock (instalación reproducible)
RUN pip install --no-cache-dir pipenv==2026.10.4
COPY Pipfile Pipfile.lock ./
RUN pipenv install --system --deploy --ignore-pipfile

COPY app.py ./
COPY templates ./templates

# HOST=0.0.0.0 solo dentro del contenedor para que sea alcanzable (ver V-05)
ENV PYTHONUNBUFFERED=1 DATABASE_PATH=/data/securedev.db HOST=0.0.0.0
EXPOSE 8000
CMD ["python", "app.py"]
