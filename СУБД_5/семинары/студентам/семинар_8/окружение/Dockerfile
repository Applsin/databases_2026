# Dockerfile
FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    LANG=C.UTF-8

# --- PostgreSQL 15 + утилиты ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-15 postgresql-client-15 postgresql-contrib-15 \
        sudo curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Python-пакеты для семинара ---
RUN pip install --no-cache-dir \
        "psycopg[binary,pool]>=3.2" \
        "sqlalchemy>=2.0" \
        pandas \
        numpy \
        jupyterlab \
        ipykernel \
        tabulate

# --- Пользователь student ---
RUN useradd -m -s /bin/bash student \
    && echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student \
    && chmod 0440 /etc/sudoers.d/student \
    && mkdir -p /home/student/work /opt/notebook \
    && chown -R student:student /home/student

# --- Ноутбук и entrypoint ---
COPY seminar8.ipynb   /opt/notebook/seminar8.ipynb
COPY entrypoint.sh    /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- Дефолтные переменные (можно переопределить через `docker run -e ...`) ---
ENV JUPYTER_PASSWORD=student \
    JUPYTER_PORT=8888 \
    POSTGRES_DB=demo

EXPOSE 8888 5432

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]