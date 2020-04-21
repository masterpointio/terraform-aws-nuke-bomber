FROM quay.io/rebuy/aws-nuke:latest as aws_nuke

FROM ubuntu:latest

RUN apt-get update \
    && apt-get install -y ca-certificates expect \
    && rm -rf /var/cache/apk/*

RUN useradd --user-group --system --create-home aws-nuke
USER aws-nuke
WORKDIR "/home/aws-nuke/"

COPY --from=aws_nuke /usr/local/bin/* /usr/local/bin/
COPY ./nuke-config.yml /home/aws-nuke/nuke-config.yml
COPY ./bomber.sh /home/aws-nuke/bomber.sh

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

ARG ACCOUNT_ID
ARG ACCOUNT_ALIAS
ENV ACCOUNT_ALIAS=$ACCOUNT_ALIAS
RUN sed -i "s/ACCOUNT_ID_TO_NUKE/$ACCOUNT_ID/g" /home/aws-nuke/nuke-config.yml

ENTRYPOINT []
CMD ["/home/aws-nuke/bomber.sh"]
