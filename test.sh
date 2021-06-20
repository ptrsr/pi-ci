#!/bin/bash
TEST_DIR="$(cd "$(dirname "$0")" && pwd)/test/"

ansible-playbook -i $TEST_DIR/hosts.yml $TEST_DIR/main.yml
