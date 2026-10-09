#!/bin/sh
# Optional deploy hook: the workflow runs this after `docker compose up -d` if
# the file exists.
#
# WHY IT IS NEEDED HERE: `up -d` does not recreate a container when the only
# change is the content of a mounted file, and prometheus and alertmanager read
# their config and rules once, at start. So a rules change was pulled by the
# deploy and then never applied -- found on 09/10, when a new alert group sat on
# disk while the running prometheus still served the two old ones. That is the
# repo and the lab diverging in silence, which is the exact failure this stack
# exists to catch.
#
# SIGHUP reloads both in place: no restart, no gap in scraping, and a bad config
# is refused while the old one keeps running. Never fails the deploy -- if a
# container is not running, `up -d` has just started it and it read the new files
# on its own.
set -u

for c in prometheus alertmanager; do
  if docker kill -s HUP "$c" >/dev/null 2>&1; then
    echo "reloaded $c"
  else
    echo "$c not running -- it started with the new config"
  fi
done
exit 0
