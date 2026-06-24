FROM python:3.10.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN groupadd --system --gid 1000 app \
    && useradd --system --uid 1000 --gid 1000 --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

COPY src /app

RUN chown -R app:app /app
USER 1000:1000

EXPOSE 5000

ENTRYPOINT ["gunicorn"]
CMD ["--bind", "0.0.0.0:5000", "main:app"]
