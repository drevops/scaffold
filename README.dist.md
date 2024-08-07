# YOURSITE
Drupal 10 implementation of YOURSITE for YOURORG

[![CircleCI](https://circleci.com/gh/your_org/your_site.svg?style=shield)](https://circleci.com/gh/your_org/your_site)
![Drupal 10](https://img.shields.io/badge/Drupal-10-blue.svg)
[![codecov](https://codecov.io/gh/your_org/your_site/graph/badge.svg)](https://codecov.io/gh/your_org/your_site)

[//]: # (#;< RENOVATEBOT)

[![RenovateBot](https://img.shields.io/badge/RenovateBot-enabled-brightgreen.svg?logo=renovatebot)](https://renovatebot.com)

[//]: # (#;> RENOVATEBOT)

[//]: # (DO NOT REMOVE THE BADGE BELOW. IT IS USED BY DREVOPS TO TRACK INTEGRATION)

[![DrevOps](https://img.shields.io/badge/DrevOps-DREVOPS_VERSION_URLENCODED-blue.svg)](https://github.com/drevops/scaffold/tree/DREVOPS_VERSION)

## Onboarding to DrevOps
Use [Onboarding checklist](docs/onboarding.md) to track the project onboarding
to DrevOps progress. Remove this section once onboarding is finished.

## Local environment setup

- Make sure that you have latest versions of all required software installed:
  - [Docker](https://www.docker.com/)
  - [Pygmy](https://github.com/pygmystack/pygmy)
  - [Ahoy](https://github.com/ahoy-cli/ahoy)
- Make sure that all local web development services are shut down (Apache/Nginx, Mysql, MAMP etc).
- Checkout project repository (in one of the [supported Docker directories](https://docs.docker.com/docker-for-mac/osxfs/#access-control)).

[//]: # (#;< ACQUIA)

- Authenticate with Acquia Cloud API
  1. Create your Acquia Cloud API token:<br/>
     Acquia Cloud UI -> Account -> API tokens -> Create Token
  2. Copy `.env.local.default` to `.env.local`.
  3. Populate `$DREVOPS_ACQUIA_KEY` and `$DREVOPS_ACQUIA_SECRET` environment
     variables in `.env.local` file with values generated in the step above.

[//]: # (#;> ACQUIA)

[//]: # (#;< LAGOON)

- Authenticate with Lagoon
  1. Create an SSH key and add it to your account in the [Lagoon Dashboard](https://ui-lagoon-master.ch.amazee.io/).
  2. Copy `.env.local.default` to `.env.local`.
  3. Update `$DREVOPS_DB_DOWNLOAD_SSH_FILE` environment variable in `.env.local` file
     with the path to the SSH key.

[//]: # (#;> LAGOON)


[//]: # (#;< !PROVISION_USE_PROFILE)

- `ahoy download-db`

[//]: # (#;> !PROVISION_USE_PROFILE)
- `pygmy up`
- `ahoy build`

## Project documentation

- [FAQs](docs/faqs.md)
- [Testing](docs/testing.md)
- [CI](docs/ci.md)
- [Releasing](docs/releasing.md)
- [Deployment](docs/deployment.md)
