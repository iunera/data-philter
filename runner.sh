#!/bin/sh
# This script downloads and runs the docker-compose setup from the repository.

set -e # Exit immediately if a command exits with a non-zero status.

URL="https://raw.githubusercontent.com/iunera/data-philter/refs/heads/main/docker-compose.yml"

if ! command -v docker &> /dev/null
then
    echo "docker could not be found, please install it first."
    exit
fi

if ! docker compose version &> /dev/null
then
    echo "'docker compose' could not be found. It is required to run this script."
    echo "Please make sure you have a recent version of Docker installed."
    exit
fi


echo "Downloading docker-compose.yml from $URL"

curl -sL "$URL" | docker compose -f - up -d

echo "Services started in the background."
echo "You can check the status with 'docker compose ps'."
