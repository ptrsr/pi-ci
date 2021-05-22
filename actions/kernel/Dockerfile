FROM ubuntu:20.04

# Install packages
ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get update

RUN apt install -y \
    git
# build-essential

COPY run.sh /run.sh

CMD /run.sh
