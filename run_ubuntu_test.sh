#!/bin/bash

# This script builds a test environment container and runs the install.sh script inside it.
# It uses Docker-in-Docker by mounting the host's Docker socket.
# It tests the scenario where the user is not in the 'docker' group and 'sudo' is required.

set -e

# Make sure install.sh is executable, as it will be mounted into the container
chmod +x install.sh

# 1. Build the test Docker image
echo "Building the test image..."
docker build -t data-philter-test -f Dockerfile.ubuntu.test .

# 2. Define the test command to be executed inside the container
# This command pre-creates the .env files to avoid interactive prompts during the test.
TEST_CMD="/bin/bash /home/testuser/install.sh"

# 3. Run the test container
echo "Running the test container..."
# Use absolute path for the current directory to mount correctly inside container
HOST_PWD=$(pwd -P)
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOST_PWD/install.sh":/home/testuser/install.sh:ro \
    -w /home/testuser \
    --name data-philter-test-container \
    data-philter-test \
    /bin/bash -c "$TEST_CMD"

echo "Test completed."
# As a manual verification step, you can check if the docker containers were started on your host machine.
# The containers are started in detached mode, so they will continue running after the test.
