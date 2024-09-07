#!/usr/bin/env bats
#
# Utilities.
#

# shellcheck disable=SC2030,SC2031,SC2129

load _helper.bash
load _helper.workflow.bash

@test "Local Ahoy commands" {
  prepare_sut "Starting utilities tests in build directory ${BUILD_DIR}"

  step "Run ahoy local commands"

  substep "Assert calling local commands without local file does not throw error"
  run ahoy --version
  assert_success
  assert_output_not_contains "[fatal]"

  substep "Assert calling local commands with local file path specified and file is present works correctly"
  cp ".ahoy.local.example.yml" ".ahoy.local.yml"
  run ahoy local help
  assert_success
  assert_output_contains "Custom local commands"
  assert_output_not_contains "[fatal]"

  substep "Assert calling local commands with local file path specified and file is present and file return non-zero exit code"

  echo >>".ahoy.local.yml"
  echo "  mylocalcommand:" >>".ahoy.local.yml"
  echo "    cmd: |" >>".ahoy.local.yml"
  echo "      echo 'expected failure'" >>".ahoy.local.yml"
  echo "      exit 1" >>".ahoy.local.yml"

  run ahoy local mylocalcommand
  assert_failure
  assert_output_contains "expected failure"
  assert_output_not_contains "[fatal]"
}

@test "Doctor info" {
  prepare_sut "Starting utilities tests in build directory ${BUILD_DIR}"
  step "Run ahoy doctor info"

  run ahoy doctor info
  assert_success
  assert_output_contains "System information report"
  assert_output_contains "Operating system"
  assert_output_contains "Docker"
  assert_output_contains "Docker Compose"
  assert_output_contains "Pygmy"
  assert_output_contains "Ahoy"
}

@test "Renovate - Check config" {
  prepare_sut "Starting utilities tests in build directory ${BUILD_DIR}"

  run npx --yes --package renovate -- renovate-config-validator --strict
  assert_success
}
