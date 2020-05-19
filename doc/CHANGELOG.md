# Changelog

## 2.0.0
### Added bulk copy project settings feature
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

## 1.0.0
### Added bulk import ussers, groups, roles and projects from CSV feature
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

## 0.0.1
### Start of development (after detailed research, learning rails/angular, studying existing plugins, creating a test plugin, etc.)
* Empty plugin template created
* Make template conform to Ruby styleguide
* Add licensing files and information
* Fill out README
* Complete the gemspec
