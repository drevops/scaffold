<?php

/**
 * @file
 * Deploy functions called from drush deploy:hook.
 *
 * @see https://www.drush.org/latest/deploycommand/
 *
 * phpcs:disable Squiz.WhiteSpace.FunctionSpacing.Before
 * phpcs:disable Squiz.WhiteSpace.FunctionSpacing.After
 */

use Drupal\Core\Extension\ExtensionDiscovery;

/**
 * Installs custom theme.
 */
function ys_core_deploy_install_theme(): void {
  \Drupal::service('theme_installer')->install(['olivero']);
  \Drupal::service('theme_installer')->install(['your_site_theme']);
  \Drupal::service('config.factory')->getEditable('system.theme')->set('default', 'your_site_theme')->save();
}

// phpcs:ignore #;< REDIS
/**
 * Enables Redis module.
 */
function ys_core_deploy_enable_redis(): void {
  $listing = new ExtensionDiscovery(\Drupal::root());
  $modules = $listing->scan('module');
  if (!empty($modules['redis'])) {
    \Drupal::service('module_installer')->install(['redis']);
  }
}

// phpcs:ignore #;> REDIS

// phpcs:ignore #;< CLAMAV
/**
 * Enables Search API and Search API Solr modules.
 */
function ys_core_deploy_enable_clamav(): void {
  $listing = new ExtensionDiscovery(\Drupal::root());
  $modules = $listing->scan('module');
  if (!empty($modules['clamav'])) {
    \Drupal::service('module_installer')->install(['media']);
    \Drupal::service('module_installer')->install(['clamav']);
  }
}

// phpcs:ignore #;> CLAMAV

// phpcs:ignore #;< SOLR
/**
 * Enables Search API and Search API Solr modules.
 */
function ys_core_deploy_enable_search_api_solr(): void {
  $listing = new ExtensionDiscovery(\Drupal::root());
  $modules = $listing->scan('module');
  if (!empty($modules['search_api']) && !empty($modules['search_api_solr']) && !empty($modules['ys_search'])) {
    \Drupal::service('module_installer')->install(['ys_search']);
  }
}
// phpcs:ignore #;> SOLR
