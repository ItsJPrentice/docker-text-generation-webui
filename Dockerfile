# syntax=docker/dockerfile:1

FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as builder

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        git \
        build-essential \
        python3-dev \
        python3-venv && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/oobabooga/GPTQ-for-LLaMa.git /build

WORKDIR /build

RUN python3 -m venv /build/venv
RUN . /build/venv/bin/activate && \
    pip3 install --upgrade pip setuptools wheel && \
    pip3 install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118 && \
    pip3 install -r requirements.txt

# https://developer.nvidia.com/cuda-gpus
# for a rtx 4090: ARG TORCH_CUDA_ARCH_LIST="8.9"
ARG TORCH_CUDA_ARCH_LIST="8.9"
RUN . /build/venv/bin/activate && \
    python3 setup_cuda.py bdist_wheel -d .



FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

LABEL maintainer="ItsJPrentice <jprentice@invalidusername.com>"
LABEL description="Docker image for GPTQ-for-LLaMa and Text Generation WebUI"

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        git \
        python3 \
        python3-pip \
        make g++  && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install virtualenv
RUN mkdir /app

RUN git clone https://github.com/oobabooga/text-generation-webui.git /app

WORKDIR /app

ARG WEBUI_VERSION
RUN test -n "${WEBUI_VERSION}" && git reset --hard ${WEBUI_VERSION} || echo "Using provided webui source"

RUN virtualenv /app/venv
RUN . /app/venv/bin/activate && \
    pip3 install --upgrade pip setuptools && \
    pip3 install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu118

COPY --from=builder /build /app/repositories/GPTQ-for-LLaMa
RUN . /app/venv/bin/activate && \
    pip3 install /app/repositories/GPTQ-for-LLaMa/*.whl

RUN . /app/venv/bin/activate && cd extensions/api && pip3 install -r requirements.txt
RUN . /app/venv/bin/activate && cd extensions/elevenlabs_tts && pip3 install -r requirements.txt
RUN . /app/venv/bin/activate && cd extensions/google_translate && pip3 install -r requirements.txt
RUN . /app/venv/bin/activate && cd extensions/silero_tts && pip3 install -r requirements.txt
RUN . /app/venv/bin/activate && cd extensions/whisper_stt && pip3 install -r requirements.txt

RUN . /app/venv/bin/activate && \
    pip3 install -r requirements.txt

RUN cp /app/venv/lib/python3.10/site-packages/bitsandbytes/libbitsandbytes_cuda118.so /app/venv/lib/python3.10/site-packages/bitsandbytes/libbitsandbytes_cpu.so

ENV CLI_ARGS=""
CMD . /app/venv/bin/activate && python3 server.py ${CLI_ARGS}