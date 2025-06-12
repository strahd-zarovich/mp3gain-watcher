FROM alpine:latest

RUN apk add --no-cache mp3gain inotify-tools bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/music"]
CMD ["/entrypoint.sh"]
