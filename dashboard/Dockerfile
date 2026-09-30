FROM python:3.12-alpine

RUN apk add --no-cache docker-cli

WORKDIR /app
COPY dashboard/server.py /app/server.py

ENV PYTHONUNBUFFERED=1
EXPOSE 8080

CMD ["python", "/app/server.py"]
