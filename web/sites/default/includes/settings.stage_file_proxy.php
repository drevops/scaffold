<?php

/**
 * @file
 * Stage file proxy settings.
 */

$origin = getenv('DRUPAL_STAGE_FILE_PROXY_ORIGIN');
if (!empty($origin) && $settings['environment'] != ENVIRONMENT_PROD) {
  $user = getenv('DRUPAL_SHIELD_USER');
  $pass = getenv('DRUPAL_SHIELD_PASS');
  if (!empty($user) && !empty($pass)) {
    $origin = str_replace('https://', "https://$user:$pass@", $origin);
  }

  $config['stage_file_proxy.settings']['origin'] = $origin;
  $config['stage_file_proxy.settings']['hotlink'] = FALSE;
}
