#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2129
#
# Helpers related to DrevOps workflow testing functionality.
#

prepare_sut() {
  step "Run SUT preparation: ${1}"
  local webroot="${2:-web}"

  SCAFFOLD_DEV_VOLUMES_MOUNTED=${SCAFFOLD_DEV_VOLUMES_MOUNTED:-1}

  assert_not_empty "${SCAFFOLD_DEV_VOLUMES_MOUNTED}"

  assert_files_not_present_common "" "" "" "${webroot}"

  substep "Initialise the project with default settings"

  # Run default install
  export DREVOPS_WEBROOT="${webroot}"
  run_installer_quiet

  assert_files_present_common "" "" "" "" "" "${webroot}"
  assert_files_present_no_provision_use_profile
  assert_files_present_deployment
  assert_files_present_no_integration_acquia "" "" "${webroot}"
  assert_files_present_no_integration_lagoon "" "" "${webroot}"
  assert_files_present_no_integration_ftp
  assert_files_present_integration_renovatebot
  assert_git_repo

  substep "Add all DrevOps files to new git repo"
  git_add_all_commit "Init DrevOps config"

  substep "Create IDE config file"
  mkdir -p .idea
  touch .idea/idea_file.txt
  assert_file_exists .idea/idea_file.txt
}

docker_remove_image() {
  docker image rm "${1}" || true
  docker image ls | grep -q -v "${1}"
}

assert_ahoy_download_db() {
  step "Run DB download"

  substep "Download the database"

  # Tests are using demo database and 'ahoy download-db' command, so we need
  # to set the CURL DB to test DB.
  #
  # Override demo database with test demo database. This is required to use
  # test assertions ("star wars") with demo database.
  #
  # Ahoy will load environment variable and it will take precedence over
  # the value in .env file.
  export DREVOPS_DB_DOWNLOAD_CURL_URL="${DREVOPS_INSTALL_DEMO_DB_TEST}"

  # Remove any previously downloaded DB dumps.
  rm -Rf .data/db.sql

  # In this test, the database is downloaded from the public URL specified in
  # DREVOPS_DB_DOWNLOAD_CURL_URL variable.
  assert_file_not_exists .data/db.sql
  ahoy download-db
  assert_file_exists .data/db.sql

  trim_file .env
}

assert_ahoy_build() {
  local webroot="${1:-web}"

  substep "Started project build"

  # Tests are using demo database and 'ahoy download-db' command, so we need
  # to set the CURL DB to test DB.
  #
  # Override demo database with test demo database. This is required to use
  # test assertions ("star wars") with demo database.
  #
  # Ahoy will load environment variable and it will take precedence over
  # the value in .env file.
  export DREVOPS_DB_DOWNLOAD_CURL_URL="${DREVOPS_INSTALL_DEMO_DB_TEST}"

  # Check that database file exists before build.
  db_file_exists=0
  [ -f ".data/db.sql" ] && db_file_exists=1

  export DREVOPS_CONTAINER_REGISTRY_USER="${TEST_DREVOPS_CONTAINER_REGISTRY_USER?Test container registry user is not set}"
  export DREVOPS_CONTAINER_REGISTRY_PASS="${TEST_DREVOPS_CONTAINER_REGISTRY_PASS?Test container registry pass is not set}"

  process_ahoyyml
  run ahoy build
  run sync_to_host

  # Assert that lock files were created.
  assert_file_exists "composer.lock"
  assert_file_exists "${webroot}/themes/custom/star_wars/package-lock.json"

  # Assert that database file preserved after build if existed before.
  if [ "${db_file_exists:-}" = "1" ]; then
    assert_file_exists .data/db.sql
  else
    assert_file_not_exists .data/db.sql
  fi

  # Assert the presence of files from the default configuration.
  assert_files_present_common "" "" "" "" "" "${webroot}"
  assert_files_present_no_provision_use_profile
  assert_files_present_deployment
  assert_files_present_no_integration_acquia "" "" "${webroot}"
  assert_files_present_no_integration_lagoon "" "" "${webroot}"
  assert_files_present_no_integration_ftp
  assert_files_present_integration_renovatebot

  # Assert only minified compiled CSS exists.
  assert_file_exists "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css"
  assert_file_not_contains "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css" "background: #7e57e2"
  assert_file_not_exists "${webroot}/themes/custom/star_wars/build/css/star_wars.css"
  # Assert only minified compiled JS exists.
  assert_file_exists "${webroot}/themes/custom/star_wars/build/js/star_wars.min.js"
  assert_file_contains "${webroot}/themes/custom/star_wars/build/js/star_wars.min.js" '!function(Drupal){"use strict";Drupal.behaviors.star_wars'
  assert_file_not_exists "${webroot}/themes/custom/star_wars/build/js/star_wars.js"

  substep "Finished project build"
}

assert_gitignore() {
  local skip_commit="${1:-0}"
  local webroot="${2:-web}"

  step "Run .gitignore test"

  create_development_settings "${webroot}"

  if [ "${skip_commit:-}" -ne 1 ]; then
    substep "Commit fully configured project"
    git_add_all_commit "Commit fully built project"
  fi

  # Assert that scaffold files were added to the git repository.
  assert_git_file_is_tracked "${webroot}/.editorconfig"
  assert_git_file_is_tracked "${webroot}/.eslintignore"
  assert_git_file_is_tracked "${webroot}/.gitattributes"
  assert_git_file_is_tracked "${webroot}/.htaccess"
  assert_git_file_is_tracked "${webroot}/autoload.php"
  assert_git_file_is_tracked "${webroot}/index.php"
  assert_git_file_is_tracked "${webroot}/robots.txt"
  assert_git_file_is_tracked "${webroot}/update.php"
  # Assert that lock files were added to the git repository.
  assert_git_file_is_tracked "composer.lock"
  assert_git_file_is_tracked "${webroot}/themes/custom/star_wars/package-lock.json"
  assert_git_file_is_not_tracked ".data/db.sql"
  # Assert that local settings were not added to the git repository.
  assert_git_file_is_not_tracked "${webroot}/sites/default/settings.local.php"
  assert_git_file_is_not_tracked "${webroot}/sites/default/services.local.yml"
  assert_git_file_is_not_tracked "docker-compose.override.yml"
  # Assert that built assets were not added to the git repository.
  assert_git_file_is_not_tracked "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css"
  assert_git_file_is_not_tracked "${webroot}/themes/custom/star_wars/build/js/star_wars.js"

  remove_development_settings "${webroot}"
}

assert_ahoy_cli() {
  step "Run ClI command"

  run ahoy cli "echo Test from inside of the container"
  assert_success
  assert_output_not_contains "Containers are not running."
  assert_output_contains "Test from inside of the container"

  # Assert that only allowed filtered variables are passed from the environment.
  export DRUPAL_UNFILTERED_VAR="drupalvar"
  export OTHER_FILTERED_VAR="othervar"

  run ahoy cli "echo \$DRUPAL_UNFILTERED_VAR"
  assert_output_contains "drupalvar"
  assert_output_not_contains "othervar"
}

assert_env_changes() {
  step "Update .env file and apply changes"

  # Assert that .env does not contain test values.
  assert_file_not_contains ".env" "MY_CUSTOM_VAR"
  assert_file_not_contains ".env" "my_custom_var_value"
  # Assert that test variable is not available inside of containers.
  run ahoy cli "printenv | grep -q MY_CUSTOM_VAR"
  assert_failure
  # Assert that test value is not available inside of containers.
  run ahoy cli 'echo $MY_CUSTOM_VAR | grep -q my_custom_var_value'
  assert_failure
  assert_output_not_contains "my_custom_var_value"

  # Add variable to the .env file and apply the change to container.
  add_var_to_file .env "MY_CUSTOM_VAR" "my_custom_var_value"
  ahoy up cli
  sync_to_container

  # Assert that .env contains test values.
  assert_file_contains ".env" "MY_CUSTOM_VAR"
  assert_file_contains ".env" "my_custom_var_value"
  # Assert that test variable and values are available inside of containers.
  run ahoy cli "printenv | grep MY_CUSTOM_VAR"
  assert_success
  assert_output_contains "my_custom_var_value"
  # Assert that test variable and value are available inside of containers.
  run ahoy cli 'echo $MY_CUSTOM_VAR | grep my_custom_var_value'
  assert_output_contains "my_custom_var_value"
  assert_success

  # Restore file, apply changes and assert that original behaviour has been restored.
  restore_file ".env"
  ahoy up cli
  sync_to_container

  assert_file_not_contains ".env" "MY_CUSTOM_VAR"
  assert_file_not_contains ".env" "my_custom_var_value"
  run ahoy cli "printenv | grep -q MY_CUSTOM_VAR"
  assert_failure
  run ahoy cli 'echo $MY_CUSTOM_VAR | grep my_custom_var_value'
  assert_failure
  assert_output_not_contains "my_custom_var_value"
}

assert_timezone() {
  step "Check that timezone can be applied"

  # Assert that .env contains a default value.
  # Note that AEDT changes to AEST during winter.
  assert_file_contains ".env" 'DREVOPS_TZ="Australia/Melbourne"'
  run docker compose exec cli date
  assert_output_contains "AE"
  run docker compose exec php date
  assert_output_contains "AE"
  run docker compose exec nginx date
  assert_output_contains "AE"
  run docker compose exec mariadb date
  assert_output_contains "AE"

  # Add variable to the .env file and apply the change to container.
  add_var_to_file .env "DREVOPS_TZ" '"Australia/Perth"'
  sync_to_container
  run ahoy up

  run docker compose exec cli date
  assert_output_contains "AWST"
  run docker compose exec php date
  assert_output_contains "AWST"
  run docker compose exec nginx date
  assert_output_contains "AWST"
  run docker compose exec mariadb date
  assert_output_contains "AWST"

  # Restore file, apply changes and assert that original behaviour has been restored.
  restore_file ".env"
  sync_to_container
  run ahoy up
  sleep 10
}

assert_ahoy_composer() {
  step "Run composer command"

  run ahoy composer about
  assert_success
  assert_output_contains "Composer - Dependency Manager for PHP - version 2."
  assert_output_contains "Composer is a dependency manager tracking local dependencies of your projects and libraries."
}

assert_ahoy_drush() {
  step "Run Drush command"

  run ahoy drush st
  assert_success
  assert_output_not_contains "Containers are not running."
}

assert_ahoy_info() {
  local webroot="${1:-web}"
  local db_image="${2:-}"

  step "Run site info"

  run ahoy info
  assert_success
  assert_output_contains "Project name                : star_wars"
  assert_output_contains "Docker Compose project name : star_wars"
  assert_output_contains "Site local URL              : http://star_wars.docker.amazee.io"
  assert_output_contains "Path to web root            : /app/${webroot}"
  assert_output_contains "DB host                     : mariadb"
  assert_output_contains "DB username                 : drupal"
  assert_output_contains "DB password                 : drupal"
  assert_output_contains "DB port                     : 3306"
  assert_output_contains "DB port on host             :"
  if [ -n "${db_image:-}" ]; then
    assert_output_contains "DB-in-image                 : ${db_image}"
  else
    assert_output_not_contains "DB-in-image             : ${db_image}"
  fi
  assert_output_contains "Solr URL on host            :"
  assert_output_contains "Selenium VNC URL on host    :"
  assert_output_contains "Mailhog URL                 : http://mailhog.docker.amazee.io/"
  assert_output_contains "Xdebug                      : Disabled ('ahoy debug' to enable)"
  assert_output_not_contains "Containers are not running."
}

assert_ahoy_container_logs() {
  step "Show container logs"

  run ahoy logs
  assert_success
  assert_output_not_contains "Containers are not running."
}

assert_ahoy_login() {
  step "Generate one-time login link"

  run ahoy login
  assert_success
  assert_output_not_contains "Containers are not running."
}

assert_ahoy_export_db() {
  step "Export DB"
  file="${1:-mydb.sql}"
  run ahoy export-db "${file}"
  assert_success
  assert_output_not_contains "Containers are not running."
  sync_to_host
  assert_file_exists ".data/${file}"
}

assert_ahoy_lint() {
  local webroot="${1:-web}"

  step "Run linter checks"

  substep "Assert that lint works"
  run ahoy lint
  assert_success

  assert_ahoy_lint_be "${webroot}"
  assert_ahoy_lint_fe "${webroot}"
}

assert_ahoy_lint_be() {
  local webroot="${1:-web}"

  step "Run BE linter checks"

  substep "Assert that BE lint failure works"
  echo '$a=1;' >>"${webroot}/modules/custom/sw_core/sw_core.module"
  sync_to_container
  run ahoy lint-be
  assert_failure

  substep "Assert that BE lint tool disabling works"
  # Replace with some valid XML element to avoid XML parsing errors.
  replace_string_content "<file>${webroot}/modules/custom</file>" "<exclude-pattern>somefile</exclude-pattern>" "$(pwd)"
  sync_to_container
  run ahoy lint-be
  assert_success
}

assert_ahoy_lint_fe() {
  local webroot="${1:-web}"

  step "Run FE linter checks"

  substep "Assert that FE lint failure works for npm lint"
  echo ".abc{margin: 0px;}" >>"${webroot}/themes/custom/star_wars/scss/components/_test.scss"
  sync_to_container
  run ahoy lint-fe
  assert_failure
  rm -f "${webroot}/themes/custom/star_wars/scss/components/_test.scss"
  ahoy cli rm -f "${webroot}/themes/custom/star_wars/scss/components/_test.scss"
  sync_to_container

  substep "Assert that FE lint failure works for Twig CS Fixer"
  mkdir -p "${webroot}/modules/custom/sw_core/templates/block"
  mkdir -p "${webroot}/themes/custom/star_wars/templates/block"
  echo "{{ set a='a' }}" >>"${webroot}/modules/custom/sw_core/templates/block/test1.twig"
  echo "{{ set b='b' }}" >>"${webroot}/themes/custom/star_wars/templates/block/test2.twig"
  sync_to_container
  run ahoy lint-fe
  assert_failure
}

assert_ahoy_test() {
  local webroot="${1:-web}"
  local is_fast="${2:-0}"

  step "Run tests"

  assert_ahoy_test_unit "${webroot}"

  assert_ahoy_test_kernel "${webroot}"

  assert_ahoy_test_functional "${webroot}"

  if [ "${is_fast:-}" == "1" ]; then
    assert_ahoy_test_bdd_fast "${webroot}"
  else
    assert_ahoy_test_bdd "${webroot}"
  fi
}

assert_ahoy_test_unit() {
  local webroot="${1:-web}"

  step "Run Drupal Unit tests"

  substep "Run all Unit tests"
  run ahoy test-unit
  assert_success
  assert_output_contains "OK ("
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"

  substep "Assert that Drupal Unit test failure works"
  # Prepare failing test.
  sed -i -e "s/assertEquals/assertNotEquals/g" "${webroot}/modules/custom/sw_core/tests/src/Unit/ExampleTest.php"
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/.logs/test_results/*
  sync_to_container

  run ahoy test-unit
  assert_failure
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"
}

assert_ahoy_test_kernel() {
  local webroot="${1:-web}"

  step "Run Drupal Kernel tests"

  substep "Run all Kernel tests"
  run ahoy test-kernel
  assert_success
  assert_output_contains "OK ("
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"

  substep "Assert that Kernel test failure works"
  # Prepare failing test.
  sed -i -e "s/assertEquals/assertNotEquals/g" "${webroot}/modules/custom/sw_core/tests/src/Kernel/ExampleTest.php"
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/.logs/test_results/*
  sync_to_container

  run ahoy test-kernel
  assert_failure
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"
}

assert_ahoy_test_functional() {
  local webroot="${1:-web}"

  step "Run Drupal Functional tests"

  substep "Run all Functional tests"
  run ahoy test-functional
  assert_success
  assert_output_contains "OK ("
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"

  substep "Assert that Functional test failure works"
  # Prepare failing test.
  sed -i -e "s/assertEquals/assertNotEquals/g" "${webroot}/modules/custom/sw_core/tests/src/Functional/ExampleTest.php"
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/.logs/test_results/*
  sync_to_container

  run ahoy test-functional
  assert_failure
  sync_to_host
  assert_file_exists ".logs/test_results/phpunit/phpunit.xml"
}

assert_ahoy_test_bdd_fast() {
  step "Run BDD tests - fast"

  # Sometimes, tests fail for random reasons. A workaround is to run BDD tests
  # to "cache" the environment and then run the tests again.
  ahoy test-bdd || true

  substep "Run all BDD tests"
  run ahoy test-bdd
  assert_success
  sync_to_host
  assert_dir_not_empty .logs/screenshots
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/.logs/test_results/*
}

assert_ahoy_test_bdd() {
  step "Run BDD tests"

  substep "Run all BDD tests"

  # Sometimes, tests fail for random reasons. A workaround is to run BDD tests
  # to "cache" the environment and then run the tests again.
  ahoy test-bdd || true

  run ahoy test-bdd
  assert_success
  sync_to_host
  assert_dir_not_empty .logs/screenshots
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/.logs/test_results/*

  substep "Run tagged BDD tests"
  assert_dir_empty .logs/screenshots
  run ahoy test-bdd -- --tags=smoke
  assert_success
  sync_to_host
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/test_results/*
  assert_dir_not_empty .logs/screenshots
  assert_file_exists ".logs/screenshots/*html"
  assert_file_exists ".logs/screenshots/*png"
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*

  substep "Assert that Behat tests failure works"
  echo 'And I should be in the "some-non-existing-page" path' >>tests/behat/features/homepage.feature
  sync_to_container
  assert_dir_empty .logs/screenshots
  run ahoy test-bdd
  assert_failure
  sync_to_host
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/test_results/*
  assert_dir_not_empty .logs/screenshots
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*

  # Remove failing step from the feature.
  trim_file tests/behat/features/homepage.feature
  sync_to_container
  restore_file .env && ahoy up cli && sync_to_container

  substep "Run a single Behat test"
  assert_dir_empty .logs/screenshots
  run ahoy test-bdd tests/behat/features/homepage.feature
  assert_success
  sync_to_host
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/test_results/*
  assert_dir_not_empty .logs/screenshots
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*

  substep "Assert that a single Behat test failure works"
  assert_dir_empty .logs/screenshots
  echo 'And I should be in the "some-non-existing-page" path' >>tests/behat/features/homepage.feature
  run ahoy up cli && sync_to_container
  run ahoy test-bdd tests/behat/features/homepage.feature
  assert_failure
  sync_to_host
  assert_dir_not_empty .logs/test_results
  assert_file_exists .logs/test_results/behat/default.xml
  rm -rf .logs/test_results/*
  ahoy cli rm -rf /app/test_results/*
  assert_dir_not_empty .logs/screenshots
  rm -rf .logs/screenshots/*
  ahoy cli rm -rf /app/.logs/screenshots/*
}

assert_ahoy_fei() {
  local webroot="${1:-web}"

  step "FE dependencies install"

  substep "Remove existing Node modules"
  rm -Rf "${webroot}/themes/custom/star_wars/node_modules" || true
  assert_dir_not_exists "${webroot}/themes/custom/star_wars/node_modules"
  sync_to_container

  substep "Install Node modules"
  run ahoy fei
  assert_success
  sync_to_host
  assert_dir_exists "${webroot}/themes/custom/star_wars/node_modules"
}

assert_ahoy_fe() {
  local webroot="${1:-web}"

  step "FE assets"

  substep "Build FE assets for production"
  assert_file_not_contains "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css" "#7e57e2"
  echo '$color-tester: #7e57e2;' >>"${webroot}/themes/custom/star_wars/scss/_variables.scss"
  echo '$color-primary: $color-tester;' >>"${webroot}/themes/custom/star_wars/scss/_variables.scss"
  sync_to_container
  ahoy fe
  sync_to_host
  assert_file_contains "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css" "background:#7e57e2"

  substep "Build FE assets for development"
  assert_file_not_contains "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css" "#91ea5e"
  echo '$color-please: #91ea5e;' >>"${webroot}/themes/custom/star_wars/scss/_variables.scss"
  echo '$color-primary: $color-please;' >>"${webroot}/themes/custom/star_wars/scss/_variables.scss"
  sync_to_container
  ahoy fed
  sync_to_host
  # Note that assets compiled for development are not minified (contains spaces
  # between properties and their values).
  assert_file_contains "${webroot}/themes/custom/star_wars/build/css/star_wars.min.css" "background: #91ea5e"
}

assert_ahoy_debug() {
  step "Xdebug"

  substep "Enable debug"
  # Assert that Xdebug is disabled by default from the inside of the container.
  run ahoy cli "php -v | grep Xdebug"
  assert_failure

  # Assert info correctly shown from the outside of the container.
  run ahoy info
  assert_success
  assert_output_contains "Xdebug"
  assert_output_contains "Disabled"
  assert_output_not_contains "Enabled"
  # Enable debugging.
  run ahoy debug
  assert_success
  # Assert that the stack has restarted.
  # Using "reat" from "Create" or "Creating".
  assert_output_contains "reat"
  assert_output_contains "Enabled debug"
  # Assert that Xdebug is enabled from the inside of the container.
  run ahoy cli "php -v | grep Xdebug"
  assert_success
  # Assert info correctly shown from the outside of the container.
  run ahoy info
  assert_success
  assert_output_not_contains "Disabled"
  assert_output_contains "Enabled"
  # Assert that command when debugging is enabled does not restart the stack.
  run ahoy debug
  assert_success
  assert_output_not_contains "reat"
  assert_output_contains "Enabled debug"

  substep "Disable debug"
  # Assert that restarting the stack does not have Xdebug enabled.
  run ahoy up
  assert_success
  # Assert that the stack has restarted.
  assert_output_contains "reat"
  # Assert that Xdebug is disabled from the inside of the container.
  run ahoy cli "php -v | grep Xdebug"
  assert_failure
  # Assert info correctly shown from the outside of the container.
  run ahoy info
  assert_success
  assert_output_contains "Xdebug"
  assert_output_contains "Disabled"
  assert_output_not_contains "Enabled"
}

assert_solr() {
  step "Solr"

  run ahoy cli curl -s "http://solr:8983/solr/drupal/select?q=*:*&rows=0&wt=json"
  assert_output_contains "response"
}

assert_redis() {
  step "Redis"

  substep "Redis service is running"
  run docker compose exec redis redis-cli FLUSHALL
  assert_output_contains "OK"

  substep "Redis integration is disabled"
  ahoy drush cr
  ahoy cli curl -L -s "http://nginx:8080" >/dev/null
  run docker compose exec redis redis-cli --scan
  assert_output_not_contains "config"
  # Redis is reported in Drupal as not connected.
  run docker compose exec cli drush core:requirements --filter="title~=#(Redis)#i" --field=severity
  assert_output_contains "Warning"

  substep "Restart with environment variable"
  add_var_to_file .env "DRUPAL_REDIS_ENABLED" "1"
  sync_to_container
  DRUPAL_REDIS_ENABLED=1 ahoy up cli
  sleep 10
  ahoy drush cr
  ahoy cli curl -L -s "http://nginx:8080" >/dev/null
  run docker compose exec redis redis-cli --scan
  assert_output_contains "config"
  # Redis is reported in Drupal as connected.
  run docker compose exec cli drush core:requirements --filter="title~=#(Redis)#i" --field=severity
  assert_output_contains "OK"

  ahoy up cli
}

assert_ahoy_reset() {
  local webroot="${1:-web}"

  step "Reset"

  # Prepare to assert that manually created file is not removed.
  touch untracked_file.txt

  create_development_settings "${webroot}"
  mkdir -p ".logs/screenshots"
  assert_dir_exists ".logs/screenshots"

  ahoy reset
  # Assert that initial DrevOps files have not been removed.
  assert_files_present_common "" "" "" "" "" "${webroot}"
  assert_files_present_deployment
  assert_files_present_no_integration_acquia "" "" "${webroot}"
  assert_files_present_no_integration_lagoon "" "" "${webroot}"
  assert_files_present_no_integration_ftp

  assert_dir_not_exists "${webroot}/modules/contrib"
  assert_dir_not_exists "${webroot}/themes/contrib"
  assert_dir_not_exists "vendor"
  assert_dir_not_exists "${webroot}/themes/custom/star_wars/node_modules"
  assert_dir_exists ".logs/screenshots"

  # Assert manually created local settings file exists.
  assert_file_exists "${webroot}/sites/default/settings.local.php"
  # Assert manually created local services file exists.
  assert_file_exists "${webroot}/sites/default/services.local.yml"
  # Assert manually created file still exists.
  assert_file_exists "untracked_file.txt"
  # Assert IDE config file still exists.
  assert_file_exists ".idea/idea_file.txt"

  assert_git_repo

  remove_development_settings "${webroot}"
}

assert_ahoy_reset_hard() {
  local webroot="${1:-web}"

  step "Reset hard"

  create_development_settings "${webroot}"

  mkdir -p ".logs/screenshots"
  assert_dir_exists ".logs/screenshots"

  ahoy reset hard

  assert_files_present_common "" "" "" "" "" "${webroot}"
  assert_files_present_deployment
  assert_files_present_no_integration_acquia "" "" "${webroot}"
  assert_files_present_no_integration_lagoon "" "" "${webroot}"
  assert_files_present_no_integration_ftp

  assert_file_not_exists "${webroot}/sites/default/settings.local.php"
  assert_file_not_exists "${webroot}/sites/default/services.local.yml"

  # Assert manually created file still exists.
  assert_file_not_exists "untracked_file.txt"
  # Assert IDE config file still exists.
  assert_file_exists ".idea/idea_file.txt"

  assert_dir_not_exists ".logs/screenshots"

  assert_git_repo

  remove_development_settings "${webroot}"
}
