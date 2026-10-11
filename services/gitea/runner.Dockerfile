FROM gitea/act_runner:0.6.1
# host-mode jobs run `docker` and JS actions (actions/checkout) directly in
# this container; the base image has neither. Previously added by hand into
# the running container, which is lost every time it's recreated.
RUN apk add --no-cache docker-cli nodejs
