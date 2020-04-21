FROM ubuntu:latest

ENV CLOUD_NUKE_VERSION=v0.1.18


RUN apt-get update && apt-get install -y wget

RUN useradd --user-group --system --create-home bomber
USER bomber
WORKDIR /home/bomber/

RUN wget -q --show-progress --progress=dot "https://github.com/gruntwork-io/cloud-nuke/releases/download/${CLOUD_NUKE_VERSION}/cloud-nuke_linux_386" \
    && mkdir -p ~/bin \
    && mv ./cloud-nuke_linux_386 ~/bin/cloud-nuke \
    && chmod u+x ~/bin/cloud-nuke

ENV PATH="/home/bomber/bin/:${PATH}"

CMD ["cloud-nuke", "aws", "--dry-run"]
