#!/bin/bash
set -e

function setup {
  # Run the Solid test-suite
  docker network create testnet

  # Build and start Nextcloud server with code from current repo contents:
  docker build -t standalone-solid-server .

  docker build -t cookie         https://github.com/pdsinterop/test-suites.git#master:servers/php-solid-server/cookie
  docker build -t pubsub-server  https://github.com/pdsinterop/php-solid-pubsub-server.git#master

  docker pull solidtestsuite/webid-provider-tests:latest
  docker tag solidtestsuite/webid-provider-tests:latest webid-provider-tests
  docker pull solidtestsuite/solid-crud-tests:v1.1.0
  docker tag solidtestsuite/solid-crud-tests:v1.1.0 solid-crud-tests
  docker pull solidtestsuite/web-access-control-tests:latest
  docker tag solidtestsuite/web-access-control-tests:latest web-access-control-tests
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
  docker run --rm --network=testnet --env COOKIE="$COOKIE" --env-file ./env-vars-for-test-image.list webid-provider-tests
  docker run --rm --network=testnet --env-file ./env-vars-for-test-image.list solid-crud-tests
}

function teardown {
  docker stop `docker ps --filter network=testnet -q`
  docker rm `docker ps --filter network=testnet -qa`
  docker network remove testnet
}

teardown || true
setup
runPss
runTests
teardown
