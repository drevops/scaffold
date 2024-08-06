@login @smoke
Feature: Login

  Ensure that user can login.

  Scenario: Login form is available.
    Given I visit "/user/login"
    Then I should see an "form#user-login-form" element
    Then I save screenshot

  @api
  Scenario: Administrator user logs in
    Given I am logged in as a user with the "administer site configuration, access administration pages" permissions
    When I go to "admin"
    Then I save screenshot

  @api @javascript
  Scenario: Administrator user logs in
    Given I am logged in as a user with the "administer site configuration, access administration pages" permissions
    When I go to "admin"
    Then I save screenshot
