<?php

namespace Drupal\your_site_core\Commands;

use Drupal\your_site_core\PostConfigImportUpdateHelper;
use Drush\Commands\DrushCommands;

/**
 * Class PostConfigImportUpdateCommands.
 *
 * @package Drush\Commands
 */
class PostConfigImportUpdateCommands extends DrushCommands {

  /**
   * Run post config import updates.
   *
   * @command post-config-import-update
   * @aliases pciu
   *
   * @see PostConfigImportUpdateHelper::registerPostConfigImportUpdate()
   * @see https://www.drupal.org/project/drupal/issues/2901418
   */
  public function run() {
    PostConfigImportUpdateHelper::runPostConfigImportUpdates();
  }

}