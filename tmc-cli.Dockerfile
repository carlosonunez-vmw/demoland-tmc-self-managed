# tmc-sm-cli is a Go program but for some reason still relies on linux-headers?
FROM ubuntu:noble
COPY ./tmc-sm /tmc-cli
RUN chmod +x /tmc-cli
RUN apt -y update
RUN apt -y install ca-certificates
ENTRYPOINT [ "/tmc-cli" ]
