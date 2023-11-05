FROM alpine:3.18

RUN apk update
RUN apk add --no-cache curl
RUN curl -o /tmp/tmc-cli https://tmc-cli.s3-us-west-2.amazonaws.com/tmc/0.5.4-a97cb9fb/linux/x64/tmc
RUN chmod +x /tmp/tmc-cli

ENTRYPOINT [ "/tmp/tmc-cli" ]
