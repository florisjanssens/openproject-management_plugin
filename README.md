# OpenProject Management Plugin

[![Build Status](https://travis-ci.com/florisjanssens/openproject-management_plugin.svg?token=Rqy6tmTtqW4aahqT8zzP&branch=master)](https://travis-ci.com/florisjanssens/openproject-management_plugin)
![Rubocop checks](https://github.com/florisjanssens/openproject-management_plugin/workflows/Rubocop%20checks/badge.svg)


This plugin adds features to OpenProject to efficiently manage users, groups, roles and projects.

More detailed information about OpenProject itself can be found at [OpenProject.org.](http://openproject.org/)

**Note:** The master branch should NOT be used to install the plugin as this branch is for development only. Please select a different branch for the version you want to install.

## Contents
* [Features](#features)
* [Requirements](#requirements)
* [Installation](#installation)
* [Interesting files](#interesting-files)
* [Credits](#credits)
* [License](#license)

## Features
This section describes the features provided by this plugin. These features can be split up into two main features.

### Bulk import users, groups, roles and projects from CSV
Gives admins the possibility to import a CSV file which performs the following functions based on the information entered in each row of the CSV:

* Create users (with an identity URL or by email invitation)
* Create groups
* Create global roles and project roles
* Create projects
* Create subprojects copied from a parent project (use the parent as a template)
  * This includes copying attributes (description, status, etc.) and associations (work packages, wiki, versions, etc.)
* Assign users to groups
* Assign users to global roles
* Assign users to projects individually or by group with a certain role

**Accessed from:** You can access this function if you are logged in as an administrator and click on one of the following links:
* Click on your Avatar in the top right of the navigation bar and click on "Bulk importer"
* Go to Administration > Users & Permissions > Users and click on "Bulk importer" next to the button to add users

**Tutorial:** You can find a complete tutorial on how to construct the CSV including a template CSV by opening the feature and clicking on the link in the notification at the top.

**Workflow:** The administrator selects a CSV and the import settings and clicks on "Import". A background job gets queued which will be picked up by a free worker process. The worker imports the CSV row-by-row. Operations resulting in an error will add an error message to the error log indicating the error and the CSV row. The importer continues importing the next rows if an error was encountered in a row. At the end, the administrator receives an email indicating how many users, groups, roles and projects were created, and also containing an error log.

### Bulk copy project settings
Gives authorized users the possibility to copy settings from a parent project to the active subprojects of the project. The user can choose which specific settings or parts of settings to copy. Settings which can be copied from the parent project to one or more subprojects are:
* Project descriptions
* Project statuses
* Public visibility of the project
* Enabled/disabled modules of the project
* Enabled/disabled state of work package types of the project
* Enabled/disabled state of custom fields of the project
* Categories of the project which do not exist yet in its subprojects (these categories are copied to each subproject of the parent that does not have the specific version yet)
* Dates, descriptions and statuses of versions for versions that have the same name in subprojects
* Versions of the project which do not exist yet in its subprojects (these versions are copied to each subproject of the parent that does not have the specific version yet)

**Accessed from:** You can access this function by going to the Project settings of a specific project that has one ore multiple subprojects and clicking on "Bulk copy settings" in the menu bar.

**Required permissions:** The user must have one of the following permissions in the project to be able to access the feature:
* Permission to edit the project
* Permission to manage versions of the project
* Permission to manage categories of the project

Based on the permissions the user has, different settings will be visible on the bulk copy page.

**The user also needs the permissions to manage the chosen settings in each subproject itself.** Not having a certain permission reports an error for the specific subproject and setting the user cannot copy but continues copying afterwards.

This allows the administrator to  create a specific role with the chosen permissions that can be given to users in projects to control which settings they can copy. *Adding the user to the parent and subprojects with the existing "Project admin" is the most likely use case however* (this role already has all the permissions).

**Workflow:** The user selects which settings to copy and clicks on "Apply". A background job gets queued which will be picked up by a free worker process. The worker copies the chosen settings to each active subproject. Operations resulting in an error will add an error message to the error log indicating the error and the specific subproject. The copy continues if an error was encountered for a specific setting and project. At the end, the user receives an email which indicates the copy is done and contains an error log.

## Requirements
This plugin has no requirements on top of the requirements of version 10.5.1 of the [OpenProject Core](https://github.com/opf/openproject/).

## Installation
### Versions
**Important:** This repository has multiple branches for different versions of OpenProject. Please select one of these versions and make sure your OpenProject version corresponds to the chosen version. The master branch should only be used to get a version which is developed alongside the OpenProject core development branch.

### In a production environment
For installation instructions, it's best to refer to [the official OpenProject documentation on how to install plugins.](https://docs.openproject.org/installation-and-operations/configuration/plugins/)

**Important:** This plugin links into the Angular frontend, so make sure to follow the instructions correctly so the Angular frontend gets recompiled.

**Important:** Make sure your production enviroment was installed by package (which is the recommended way). Using the Docker version for example requires you to modify the Docker image and does not guarantee all functionalities to work.

### In a development environment
If you want to install the plugin in a development environment, you can follow [this part of the official documentation on how to create an OpenProject plugin.](https://docs.openproject.org/development/create-openproject-plugin/#hook-the-new-plugin-into-openproject)

This also requires that you installed the OpenProject development environment first. For Ubuntu/Debian, you can follow [this tutorial of the official documentation.](https://docs.openproject.org/development/development-environment-ubuntu/)

The plugin also links into the Angular frontend. This requires the frontend of the plugin being linked to the plugin of the core. The documentation does not mention how to do this. **To link the frontends, execute the following command:**

    ./bin/rake openproject:plugins:register_frontend

**Important:** Do NOT use the Docker development environment to install the plugin. At the moment, the Docker development environment does not support background jobs for example which breaks some functionalities of the core itself. This plugin also uses background jobs as an important part of the functionalities.

## Interesting files
* `app/workers/*` files which contain the code for the background jobs which perform the main functionalities of the features
* `lib/open_project/management_plugin/patches/*` contains patches which add actions to the existing ProjectsController and UsersController. The features extend the functionality of these existing controllers by using these actions
* `lib/open_project/management_plugin/engine.rb` the engine that will be hooked into the OpenProject core. Shows how to add actions to permissions, add menu items with conditions, add hooks, register patches, precompile assets, etc.
* `config/routes.rb` contains the routes the plugin adds
* `frontend/module/*` contains the Angular frontend of the plugin (used for the form of the bulk CSV import feature)
* `app/views/{users|project_settings}/*` contains the main views of the features
* `app/mailers/*`  contains the mailers responsible for the mails delivered to the user upon job completion for each feature. `app/views/{bulk_project_setter_mailer|user_import_mailer}/*` contains the HTML/text templates used for the mails. `app/views/layouts/*` contains the layouts for the mails
* `app/controllers/project_settings/bulk_setter_controller.rb` renders the main view of the project settings bulk copier feature when the menu item in a project with subprojects is clicked
* `app/assets/*` contains the assets used throughout the plugin
* `app/contracts/*` contains Trailblazer Reform contracts which did not exist yet in the core (for categories, groups and principal roles)
* `app/services/*` contains services which did not exist yet in the core (to create categories, groups, principal_roles through the Trailblazer Reform contracts)
* `lib/open_project/management_plugin/hooks.rb` contains the hooks the plugin uses. `app/views/hooks/management_plugin/*` contains partials rendered for specific hooks
* `spec/*` contains RSpec specs for unit/integration/acceptance tests of the features


## Credits
The OpenProject Management Plugin was created by Floris Janssens.

## License
This plugin is licensed under the GNU GPL v3. See doc/COPYRIGHT.md and doc/GPL.txt for more details.

Copyright (C) 2012-2020 the OpenProject GmbH
