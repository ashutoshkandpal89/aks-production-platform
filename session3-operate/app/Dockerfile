FROM python:3.12-slim
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
WORKDIR /app
COPY app.py .
USER 10001
EXPOSE 8080
CMD ["python", "-u", "app.py"]
