FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends chromium chromium-driver && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir selenium==4.27.1 pytest==8.3.4
WORKDIR /tests
COPY test_site.py .
CMD ["python", "-m", "pytest", "-v", "--junitxml=/results/junit.xml"]
