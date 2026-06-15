FROM python:3.11-slim
WORKDIR /connectongs
COPY . .
RUN pip install --no-cache-dir bcrypt 2>/dev/null || true
VOLUME ["/data"]
ENV PORT=8080
ENV HOST=0.0.0.0
ENV DATA_DIR=/data
ENV NODE_ID=node1
ENV RPC_PORT=9100
ENV PEER_NODES=""
ENV PYTHONUNBUFFERED=1
EXPOSE 8080 9100
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import socket; s=socket.create_connection(('localhost',8080),2); s.close()" || exit 1
CMD ["python", "main.py"]
