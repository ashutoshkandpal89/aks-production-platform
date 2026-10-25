FROM python:3.12-slim

# Non-root user, no shell, nothing writable at runtime (see the manifest)
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
USER 10001

EXPOSE 8080
CMD ["python", "-u", "app.py"]
