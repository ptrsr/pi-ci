#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/../"
TEST_DIR="$PROJECT_DIR/test/"

ansible-playbook -i $TEST_DIR/hosts.yml $TEST_DIR/main.yml
