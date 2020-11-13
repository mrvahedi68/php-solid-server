#!/bin/bash
set -e

function setup {
  # Run the Solid test-suite
  docker network create testnet

  # Build and start Nextcloud server with code from current repo contents:
  docker build --no-cache -t standalone-solid-server .

  docker build -t webid-provider https://github.com/pdsinterop/test-suites.git#master:/testers/webid-provider
  #docker build -t solid-crud https://github.com/solid/test-suite.git#master:/testers/solid-crud
  docker build --no-cache -t solid-crud https://github.com/solid/test-suite.git#master:/testers/solid-crud
  #docker build -t cookie         https://github.com/solid/test-suite.git#master:helpers/cookie
  docker build -t cookie         https://github.com/pdsinterop/test-suites.git#master:servers/php-solid-server/cookie
  docker build -t pubsub-server  https://github.com/pdsinterop/php-solid-pubsub-server.git#master
}

function runPss {
  docker run -d --name server --network=testnet --env-file ./env-vars-for-test-image.list standalone-solid-server

  docker run -d --name pubsub --network=testnet pubsub-server

  until docker run --rm --network=testnet webid-provider curl -kI https://server 2> /dev/null > /dev/null
  do
    echo Waiting for server to start, this can take up to a minute ...
    docker ps -a
    docker logs server
    sleep 1
  done
  docker ps -a
  docker logs server

  echo Getting cookie...
  export COOKIE="`docker run --rm --cap-add=SYS_ADMIN --network=testnet -e SERVER_TYPE=php-solid-server --env-file ./env-vars-for-test-image.list cookie`"
}

function runTests {
  echo "Running webid-provider tests with cookie $COOKIE"
  docker run --rm --network=testnet --env COOKIE="$COOKIE" --env-file ./env-vars-for-test-image.list webid-provider
  docker run --rm --network=testnet --env-file ./env-vars-for-test-image.list solid-crud
}

function teardown {
  docker stop server
  docker rm server
  docker stop pubsub
  docker rm pubsub
  docker network remove testnet
}

setup
runPss
runTests
teardown
