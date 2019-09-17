FROM alpine:latest

LABEL "com.github.actions.name"="Commit Message Checker"
LABEL "com.github.actions.description"="Checks commits messages according to given regex"
LABEL "com.github.actions.icon"="activity"
LABEL "com.github.actions.color"="yellow"

RUN apk add --no-cache \
	bash \
	ca-certificates \
	coreutils \
	curl \
	jq

COPY main.sh /usr/local/bin/main

CMD ["main"]