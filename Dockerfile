
# syntax=docker/dockerfile:1

# ── Base: Python 3.10 on Debian Bookworm ──────────────────────────────────────

# OpenTracer has no upstream Dockerfile. This file was developed as part of

# a reproducibility study. Python 3.10 is chosen to match Trace2Inv (the FSE

# 2024 artifact built on top of OpenTracer).

FROM python:3.10-slim

# ── system deps ────────────────────────────────────────────────────────────────

# git              – crytic-compile/slither resolves contract imports via git

# curl             – solc-select downloads compiler binaries on demand

# build-essential + libssl-dev + libffi-dev – native C wheels (cytoolz, etc.)

# sqlite3          – used by crawlPackage/cacheDatabase.py

RUN apt-get update \

    && apt-get install -y --no-install-recommends \

        git \

        curl \

        build-essential \

        libssl-dev \

        libffi-dev \

        ca-certificates \

        sqlite3 \

    && rm -rf /var/lib/apt/lists/*

WORKDIR /OpenTracer

# ── copy source ────────────────────────────────────────────────────────────────

COPY . /OpenTracer/

# ── Python deps + solc-select ──────────────────────────────────────────────────

# solc-select is installed so Slither can invoke the correct solc version

# on demand at runtime.

# Note: vyper omitted — vyper==0.2.8 requires Python ≤3.8, incompatible with 3.10.

# Note: TrueBlocks (chifra) is a system tool installed separately at runtime.

RUN pip install --no-cache-dir --upgrade pip \

    && pip install --no-cache-dir -r requirements.txt \

    && pip install --no-cache-dir solc-select

# ── offline smoke test ─────────────────────────────────────────────────────────

# hadolint ignore=SC2015

RUN python3.10 -c "\

import sys, importlib.util; \

pkgs = ['eth_abi', 'hexbytes', 'numpy', 'packaging', \

        'requests', 'slither', 'toml', 'tomlkit', 'web3']; \

missing = [p for p in pkgs if importlib.util.find_spec(p) is None]; \

[print(f'  ok  {p}') for p in pkgs if p not in missing]; \

[print(f'  MISSING  {p}', file=sys.stderr) for p in missing]; \

sys.exit(1) if missing else print('Smoke test passed.')"

# ── runtime note ───────────────────────────────────────────────────────────────

# settings.toml holds secrets: EtherScanApiKeys, rpcProviders, ethArchives.

# Mount it at runtime — never bake it into the image:

#   docker run -v $(pwd)/settings.toml:/OpenTracer/settings.toml:ro ...

#

# TrueBlocks (chifra) must be installed on the host and mounted or installed

# separately — it is a system-level tool not available via pip.

#

# Usage: docker run ... python3.10 main.py

CMD ["python3.10", "-c", "print('OpenTracer ready. Usage: python3.10 main.py')"]

