FROM quay.io/rebuy/aws-nuke:latest as aws_nuke

# Using ubuntu instead of the aws-nuke to get easy access to `expect`
FROM ubuntu:latest

RUN apt-get update \
    && apt-get install -y ca-certificates expect \
    && rm -rf /var/cache/apk/*

RUN useradd --user-group --system --create-home aws-nuke
USER aws-nuke
WORKDIR /home/aws-nuke/

COPY --from=aws_nuke /usr/local/bin/* /usr/local/bin/
COPY ./nuke-config.yml /home/aws-nuke/nuke-config.yml
COPY ./bomber.sh /home/aws-nuke/bomber.sh

ARG ACCOUNT_ALIAS
ENV ACCOUNT_ALIAS=$ACCOUNT_ALIAS
ARG NOT_A_DRILL="false"
ENV NOT_A_DRILL=$NOT_A_DRILL

ARG ACCOUNT_ID
RUN sed -i "s/ACCOUNT_ID_TO_NUKE/$ACCOUNT_ID/g" /home/aws-nuke/nuke-config.yml

ENTRYPOINT []
CMD ["/home/aws-nuke/bomber.sh"]
