FROM quay.io/rebuy/aws-nuke:latest

COPY ./nuke-config.yml /home/aws-nuke/nuke-config.yml

ENTRYPOINT ["/usr/local/bin/aws-nuke"]
CMD ["-c", "/home/aws-nuke/nuke-config.yml", "--force", "--force-sleep", "3"]
