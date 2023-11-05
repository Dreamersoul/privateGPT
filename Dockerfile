### IMPORTANT, THIS IMAGE CAN ONLY BE RUN IN LINUX DOCKER
### You will run into a segfault in mac
FROM wallies/python-cuda:3.11-cuda12.2-runtime as base

# Install poetry
RUN pip install pipx
RUN python3 -m pipx ensurepath
RUN pipx install poetry
ENV PATH="/root/.local/bin:$PATH"

# Dependencies to build llama-cpp and wget
RUN apt update && apt install -y \
  libopenblas-dev\
  ninja-build\
  build-essential\
  pkg-config\
  wget

# https://python-poetry.org/docs/configuration/#virtualenvsin-project
ENV POETRY_VIRTUALENVS_IN_PROJECT=true

FROM base as dependencies
WORKDIR /home/worker/app
COPY pyproject.toml poetry.lock ./

RUN poetry install --with ui,local

RUN CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install --force-reinstall --no-cache-dir llama-cpp-python

FROM base as app

ENV PYTHONUNBUFFERED=1
ENV PORT=8080
ENV PGPT_PROFILES=docker
EXPOSE 8080

# Prepare a non-root user
RUN adduser --system worker
WORKDIR /home/worker/app

RUN mkdir local_data; chown worker local_data
RUN mkdir models; chown worker models
COPY --chown=worker --from=dependencies /home/worker/app/.venv/ .venv
COPY --chown=worker private_gpt/ private_gpt
COPY --chown=worker docs/ docs
COPY --chown=worker *.yaml *.md ./
COPY --chown=worker models/ models/

USER worker
ENTRYPOINT .venv/bin/python -m private_gpt