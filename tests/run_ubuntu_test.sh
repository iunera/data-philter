#!/bin/bash

# This script builds a test environment container and runs the install.sh script inside it.
# It uses Docker-in-Docker by mounting the host's Docker socket.
# It tests the scenario where the user is not in the 'docker' group and 'sudo' is required.

set -e

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Make sure install.sh is executable, as it will be mounted into the container
chmod +x "$PROJECT_ROOT/install.sh"

# 1. Build the test Docker image
echo "Building the test image..."
docker build -t data-philter-test -f "$SCRIPT_DIR/Dockerfile.ubuntu.test" "$PROJECT_ROOT"

# 2. Define the test command to be executed inside the container
# This command pre-creates the .env files to avoid interactive prompts during the test.
TEST_CMD="/bin/bash /home/testuser/install.sh"

# 3. Run the test container
echo "Running the test container..."
docker run --rm -it \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PROJECT_ROOT/install.sh":/home/testuser/install.sh:ro \
    -w /home/testuser \
    --name data-philter-test-container \
    data-philter-test \
    /bin/bash -c "$TEST_CMD"

echo "Test completed."
# As a manual verification step, you can check if the docker containers were started on your host machine.
# The containers are started in detached mode, so they will continue running after the test.
