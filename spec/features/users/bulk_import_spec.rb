#-- copyright
# OpenProject management plugin.
# Copyright (C) 2020 Floris Janssens (florisjanssens@outlook.com)
#
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.md for more details.
#++

require 'spec_helper'

feature 'Bulk CSV import', type: :feature, js: true do
  given(:current_user) { FactoryBot.create(:admin) }

  given!(:default_project_role) { FactoryBot.create(:role, name: default_project_role_name) }
  given(:default_project_role_name) { "Member" }

  given(:header) { "username,email,first_name,last_name,identity_url,administrator,group,role,parent_project,sub_project" }
  given(:row2) { "john.doe@gmail.com,john.doe@gmail.com,John,Doe,u0001,true,,,," }
  given(:rows) do
    [header,
     row2]
  end

  given(:file_path) { "tmp/test.csv" }

  given(:csv) do
    CSV.open(file_path, "w") do |csv|
      rows.each do |row|
        csv << row.split(",")
      end
    end
  end

  given(:authentication_by_identity) { "Identity URL" }
  given(:authentication_by_password) { "Password (email invitation)" }
  given(:identity_url_prefix) { "saml" }
  given(:create_non_existing) { true }

  after(:each) { File.delete(file_path) if csv }

  background do
    csv # Constructs the CSV

    login_as current_user

    clear_enqueued_jobs
    clear_performed_jobs

    visit bulk_import_path
  end

  context "as a user who is not an administrator" do
    given(:current_user) { FactoryBot.create(:user) }

    scenario "navigating to the bulk CSV import page shows the unauthorized message" do
      expect(page).to have_selector('.notification-box--content', text: "[Error 403]")
    end

    scenario "the import users button is not visible in the top menu" do
      expect_top_menu_item("Bulk importer", present: false)
    end
  end

  context "as an admin" do
    scenario "the bulk importer button is visible in the top menu" do
      expect_top_menu_item("Bulk importer", present: true)
    end

    scenario "the import users button is visible in the users page" do
      visit users_path

      expect(page).to have_selector('.toolbar-item span.button--text', text: "Bulk Importer")
    end

    scenario "entering an invalid identity URL prefix when authenticating by identity URL shows an error" do
      perform_import(file: file_path,
                     authentication_by: authentication_by_identity,
                     identity_url_prefix: "")

      message = page.find("#identity_url_prefix_textfield").native.attribute("validationMessage")
      expect(message).to eq "Please fill out this field."

      perform_import(file: file_path,
                     authentication_by: authentication_by_identity,
                     identity_url_prefix: "%invalid")

      message = page.find("#identity_url_prefix_textfield").native.attribute("validationMessage")
      expect(message).to eq "Please match the requested format."
    end

    context "with an invalid CSV file" do
      given(:file_path) { "tmp/invalid.txt" }

      scenario "selecting an invalid CSV file disables the import button and shows an error" do
        select_csv(file_path)

        expect(page).to have_selector(".csv--error-pane", text: "The file you selected is not a CSV")
        expect(page).to have_no_selector(:link_or_button, 'Import')
      end

      scenario "when no CSV file is selected, the import button is disabled" do
        expect(page).to have_no_selector(:link_or_button, 'Import')
      end
    end

    context "with a CSV file missing some header columns" do
      given(:header) { "first_name,last_name,administrator,group,role,parent_project,sub_project" }
      given(:row2) { "John,Doe,true,,,," }

      scenario "importing the CSV shows an error indicating which headers are missing" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix)

        expect_missing_header_errors(["username", "email", "identity_url"])
      end

      scenario "using the email invite authentication method does not require the identity_url column" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_password)

        expect_missing_header_errors(["username", "email"])
      end
    end

    context "with a valid CSV file containing the column combination to create a user" do
      given(:row2) { "john.doe@gmail.com,john.doe@gmail.com,John,Doe,u0001,false,,,," }

      scenario "import a user with an identity URL" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix)

        expect_successful_notification

        expect_user(username: "john.doe@gmail.com",
                    mail: "john.doe@gmail.com",
                    firstname: "John",
                    lastname: "Doe",
                    status: User::STATUSES[:active],
                    identity_url: "#{identity_url_prefix}:u0001",
                    admin: false)

        expect_successful_import_mail(users: 1)
      end

      scenario "import a user which receives an email invite" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_password)

        expect_successful_notification

        expect_user(username: "john.doe@gmail.com",
                    mail: "john.doe@gmail.com",
                    firstname: "John",
                    lastname: "Doe",
                    status: User::STATUSES[:invited],
                    admin: false)

        expect_user_invited_mail("john.doe@gmail.com")
        expect_successful_import_mail(users: 1)
      end

      context "that already exists" do
        let!(:existing_user) { FactoryBot.create(:user, login: "john.doe@gmail.com") }

        scenario "importing an existing user makes no changes" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_non_matching_user_attributes(username: "john.doe@gmail.com",
                                              mail: "john.doe@gmail.com",
                                              firstname: "John",
                                              lastname: "Doe")

          expect_successful_import_mail
        end
      end
    end

    context "with a valid CSV file containing the column combination to create a group and add a member" do
      given(:row2) { "jane.doe@gmail.com,,,,,,Group 1,,," }
      given!(:existing_user) { FactoryBot.create(:user, login: "jane.doe@gmail.com") }

      scenario "import a group and add the user to the group" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix)

        expect_successful_notification

        expect_group_with_members(groupname: "Group 1", members: [existing_user])

        expect_successful_import_mail(groups: 1)
      end

      context "and the group already exists" do
        given!(:group) { FactoryBot.create(:group, groupname: "Group 1") }

        scenario "add the user to the existing group" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_group_with_members(groupname: "Group 1", members: [existing_user])

          expect_successful_import_mail(groups: 0)
        end
      end
    end

    context "with a valid CSV file containing the column combination to create a global role " \
            "with an existing user appointed to it" do
      given(:row2) { "jane.doe@gmail.com,,,,,,,Global role 1,," }
      given!(:existing_user) { FactoryBot.create(:user, login: "jane.doe@gmail.com") }

      scenario "import a global role and add the user to the role" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix)

        expect_successful_notification

        expect_global_role_with_members(role_name: "Global role 1", members: [existing_user])

        expect_successful_import_mail(roles: 1)
      end

      context "and the role already exists" do
        given!(:global_role) { FactoryBot.create(:global_role, name: "Global role 1") }

        scenario "add the user to the existing group" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_global_role_with_members(role_name: "Global role 1", members: [existing_user])

          expect_successful_import_mail(roles: 0)
        end
      end

      context "and the role already exists as a project role" do
        given!(:role) { FactoryBot.create(:role, name: "Global role 1") }

        scenario "importing a project role as a global role reports an error" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          error_msg = "At line 2 (while adding user to role): The specified role is not a global role. If no parent or " \
                      "sub-project wasfilled in, the role should be a new role or an existing global role."
          expect_successful_import_mail(roles: 0, errors: [error_msg])
        end
      end
    end

    context "with a valid CSV file containing the column combination to create a project" do
      given(:row2) { "jane.doe@gmail.com,,,,,,,Project role 1,parent-project-1," }
      given!(:existing_user) { FactoryBot.create(:user, login: "jane.doe@gmail.com") }

      context "as a subproject copied from an existing parent project" do
        given(:row2) { "jane.doe@gmail.com,,,,,,,Project role 1,parent-project-1,sub-project-1" }
        given!(:project_status) { FactoryBot.create(:project_status) }
        given!(:project_public) { true }
        given!(:project_description) { "The best project ever." }
        given!(:project_modules) { OpenProject::AccessControl.available_project_modules }
        given!(:custom_field_1) { FactoryBot.create(:work_package_custom_field) }
        given!(:custom_field_2) { FactoryBot.create(:work_package_custom_field) }
        given!(:parent_project) do
          FactoryBot.create(:project_with_types,
                            identifier: "parent-project-1",
                            description: project_description,
                            public: project_public,
                            status: project_status,
                            enabled_module_names: project_modules,
                            work_package_custom_field_ids: [custom_field_1.id, custom_field_2.id])
        end
        given!(:category_1) { FactoryBot.create(:category, project: parent_project) }
        given!(:version_1) { FactoryBot.create(:version, project: parent_project) }
        given!(:work_package) { FactoryBot.create(:work_package, project: parent_project) }
        given!(:wiki) { parent_project.wiki }
        let!(:wiki_page) do
          FactoryBot.create :wiki_page_with_content,
                            title: 'Attached',
                            wiki: wiki,
                            attachments: [FactoryBot.build(:attachment, container: nil, filename: 'attachment.pdf')]
        end

        scenario "import a subproject copied from a parent project and assign a member" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_subproject_copied(parent: "parent-project-1",
                                   subproject: "sub-project-1",
                                   versions: [version_1],
                                   categories: [category_1],
                                   work_packages: [work_package])

          expect_members_role_in_project(project_identifier: "sub-project-1",
                                         role_name: "Project role 1",
                                         members: [existing_user])

          expect_successful_import_mail(roles: 1, projects: 1)
        end
      end

      context "and assign the user to the project with a new role" do
        scenario "import a project and role, and add the user to the project with the role" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_members_role_in_project(project_identifier: "parent-project-1",
                                         role_name: "Project role 1",
                                         members: [existing_user])

          expect_successful_import_mail(roles: 1, projects: 1)
        end
      end

      context "and assign the user to the project with an existing role" do
        given!(:role) { FactoryBot.create(:role, name: "Project role 1") }

        scenario "import a project, and add the user to the project with the role" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_members_role_in_project(project_identifier: "parent-project-1",
                                         role_name: "Project role 1",
                                         members: [existing_user])

          expect_successful_import_mail(roles: 0, projects: 1)
        end
      end

      context "and assign the user to the project with a role that exists as a global role" do
        given!(:global_role) { FactoryBot.create(:global_role, name: "Project role 1") }

        scenario "assigning a user to a project with a global role reports an error" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          error_msg = "At line 2 (while adding user to project): The specified role is an existing global role. " \
                      "If a parent or sub-project was filled in,the role should be a new role or an existing project role."
          expect_successful_import_mail(roles: 0, projects: 1, errors: [error_msg])
        end
      end

      context "and assign the user to the project with the default role" do
        given(:row2) { "jane.doe@gmail.com,,,,,,,,parent-project-1," }

        scenario "assigning a user to a project without specifying a role uses the default role" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_members_role_in_project(project_identifier: "parent-project-1",
                                         role_name: default_project_role_name,
                                         members: [existing_user])

          expect_successful_import_mail(roles: 0, projects: 1)
        end

        context "that doesn't exist yet" do
          given(:default_project_role) { nil }

          scenario "assigning a user to a project without specifying a role uses and creates the default role" do
            perform_import(file: file_path,
                           authentication_by: authentication_by_identity,
                           identity_url_prefix: identity_url_prefix)

            expect_successful_notification

            expect_members_role_in_project(project_identifier: "parent-project-1",
                                           role_name: default_project_role_name,
                                           members: [existing_user])

            expect_successful_import_mail(roles: 1, projects: 1)
          end
        end
      end

      context "and assign the users of a group to the project with a role" do
        given(:row2) { "jane.doe@gmail.com,,,,,,Group 1,Project role 1,parent-project-1," }
        given!(:group) { FactoryBot.create(:group, groupname: "Group 1") }

        scenario "import a project and assign a group to the project" do
          perform_import(file: file_path,
                         authentication_by: authentication_by_identity,
                         identity_url_prefix: identity_url_prefix)

          expect_successful_notification

          expect_members_role_in_project(project_identifier: "parent-project-1", role_name: "Project role 1", members: [group])

          expect_successful_import_mail(groups: 0, roles: 1, projects: 1)
        end
      end
    end

    context "With the create non existing option disabled and a valid CSV file" do
      given(:row2) { "jane.doe@gmail.com,,,,,,Group 1,Project role 1,parent-project-1,sub-project-1" }
      given!(:existing_user) { FactoryBot.create(:user, login: "jane.doe@gmail.com") }

      scenario "importing non-existing groups, roles and projects with the create " \
               "non existing option disabled reports errors per row" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix,
                       create_non_existing: false)

        expect_successful_notification

        error_msg = "At line 2 (while creating group): You chose to not create non-existing objects, " \
                    "the specified group should exist beforehand."
        expect_successful_import_mail(errors: [error_msg])
      end
    end

    context "With a valid CSV file containing multiple rows using all functions at once" do
      given(:row2) { "john.doe@gmail.com,john.doe@gmail.com,John,Doe,u0001,true,,,," }
      given(:row3) { "jane.doe@gmail.com,jane.doe@gmail.com,Jane,Doe,u0002,false,,,," }
      given(:row4) { "jane.doe@gmail.com,jane.doe@gmail.com,Jane,Doe,u0002,false,Group 1,,," }
      given(:row5) { "jane.doe@gmail.com,,,,,,Group 2,,," }
      given(:row6) { "jane.doe@gmail.com,,,,,,,Global role 1,," }
      given(:row7) { "jane.doe@gmail.com,,,,,,Group 3,Global role 2,," }
      given(:row8) { "jane.doe@gmail.com,,,,,,,Project role 1,parent-project-1," }
      given(:row9) { "jane.doe@gmail.com,,,,,,,,parent-project-1," }
      given(:row10) { "jane.doe@gmail.com,,,,,,,Project role 1,,parent-project-2" }
      given(:row11) { "jane.doe@gmail.com,,,,,,,Project role 1,parent-project-1,sub-project-1" }
      given(:row12) { "jane.doe@gmail.com,,,,,,Group 4,Project role 1,parent-project-3," }
      given(:row13) { "foo.bar@gmail.com,foo.bar@gmail.com,Foo,Bar,,false,,,," }
      given(:row14) { "jane.doe@gmail.com,,,,,,Group 3,Global role 2,," }
      given(:rows) do
        [header,
         row2,
         row3,
         row4,
         row5,
         row6,
         row7,
         row8,
         row9,
         row10,
         row11,
         row12,
         row13,
         row14]
      end

      scenario "importing users, groups, roles, projects and assigning memberships in bulk" do
        perform_import(file: file_path,
                       authentication_by: authentication_by_identity,
                       identity_url_prefix: identity_url_prefix)

        expect_successful_notification

        expect_user(username: "john.doe@gmail.com",
                    mail: "john.doe@gmail.com",
                    firstname: "John",
                    lastname: "Doe",
                    status: User::STATUSES[:active],
                    identity_url: "#{identity_url_prefix}:u0001",
                    admin: true)
        user2 = expect_user(username: "jane.doe@gmail.com",
                            mail: "jane.doe@gmail.com",
                            firstname: "Jane",
                            lastname: "Doe",
                            status: User::STATUSES[:active],
                            identity_url: "#{identity_url_prefix}:u0002",
                            admin: false)

        expect_group_with_members(groupname: "Group 1", members: [user2])
        expect_group_with_members(groupname: "Group 2", members: [user2])
        expect_group_with_members(groupname: "Group 3", members: [user2])
        group4 = expect_group_with_members(groupname: "Group 4", members: [user2])

        expect_global_role_with_members(role_name: "Global role 1", members: [user2])
        expect_global_role_with_members(role_name: "Global role 2", members: [user2])

        expect_members_role_in_project(project_identifier: "parent-project-1",
                                       role_name: "Project role 1",
                                       members: [user2])
        expect_members_role_in_project(project_identifier: "parent-project-1",
                                       role_name: default_project_role_name,
                                       members: [user2])
        expect_members_role_in_project(project_identifier: "parent-project-2",
                                       role_name: "Project role 1",
                                       members: [user2])
        expect_members_role_in_project(project_identifier: "sub-project-1",
                                       role_name: "Project role 1",
                                       members: [user2])
        expect_members_role_in_project(project_identifier: "parent-project-3",
                                       role_name: "Project role 1",
                                       members: [group4])

        expect_subproject_copied(parent: "parent-project-1", subproject: "sub-project-1")

        error_msg = "At line 13 (while checking user fields): The 'identity_url' column can't be blank."
        expect_successful_import_mail(users: 2, groups: 4, roles: 3, projects: 4, errors: [error_msg])
      end
    end
  end

  def expect_subproject_copied(parent:, subproject:, versions: [], categories: [], work_packages: [])
    parent = expect_project_present(parent)
    subproject = expect_subproject_present(parent: parent, subproject_identifier: subproject)

    expect_work_package_types_copied(from: parent, to: subproject)
    expect_enabled_modules_copied(from: parent, to: subproject)
    expect_public_state_copied(from: parent, to: subproject)
    expect_description_copied(from: parent, to: subproject)
    expect_status_copied(from: parent, to: subproject)

    expect_versions_to_exist(in_project: subproject, versions: versions)
    expect_categories_to_exist(in_project: subproject, categories: categories)
    expect_version_attributes_copied(to: subproject, from_versions: versions)

    expect_work_packages_copied(to: subproject, from_work_packages: work_packages)
    expect_wiki_copied(from: parent, to: subproject)
  end

  def expect_subproject_present(parent:, subproject_identifier:)
    subproject = expect_project_present(subproject_identifier)

    expect(subproject.parent_id).to eq(parent.id)

    subproject
  end

  def expect_work_packages_copied(to:, from_work_packages:)
    from_work_packages.each do |wp|
      sub_wp = to.work_packages.find_by(subject: wp.subject)

      expect(sub_wp).to be_present
      expect(sub_wp.description).to eq(wp.description)
    end
  end

  def expect_wiki_copied(from:, to:)
    expect(wiki_pages_count(to)).to eq(wiki_pages_count(from))

    if wiki_pages_count(from).positive?
      from.wiki.pages.each do |page|
        copied_page = find_wiki_page(project: to, page_title: page.title)
        expect_wiki_page_copied(original_page: page, copied_page: copied_page)
      end
    end
  end

  def expect_wiki_page_copied(original_page:, copied_page:)
    expect(copied_page).not_to be_nil
    expect(wiki_page_attachment_count(copied_page))
      .to eq(wiki_page_attachment_count(original_page))
    expect(get_wiki_page_first_attachment_name(copied_page))
      .to eq get_wiki_page_first_attachment_name(original_page)
  end

  def get_wiki_page_first_attachment_name(wiki_page)
    wiki_page.attachments.first.filename
  end

  def find_wiki_page(project:, page_title:)
    project.wiki.find_page page_title
  end

  def wiki_pages_count(project)
    project.wiki.pages.count
  end

  def wiki_page_attachment_count(wiki_page)
    wiki_page.attachments.count
  end

  def expect_version_attributes_copied(to:, from_versions:)
    from_versions.each do |version|
      sub_version = to.versions.find_by(name: version.name)

      expect_same_version_dates(version1: version, version2: sub_version)
      expect_same_version_description(version1: version, version2: sub_version)
      expect_same_version_status(version1: version, version2: sub_version)
    end
  end

  def expect_same_version_status(version1:, version2:)
    expect(version2.status).to eq(version1.status)
  end

  def expect_same_version_description(version1:, version2:)
    expect(version2.description).to eq(version1.description)
  end

  def expect_same_version_dates(version1:, version2:)
    expect(version2.start_date).to eq(version1.start_date)
    expect(version2.effective_date).to eq(version1.effective_date)
  end

  def expect_versions_to_exist(in_project:, versions:)
    versions.each do |version|
      expect(in_project.versions.find_by(name: version.name)).to be_present
    end
  end

  def expect_categories_to_exist(in_project:, categories:)
    categories.each do |category|
      expect(in_project.categories.find_by(name: category.name)).to be_present
    end
  end

  def expect_custom_fields_copied(from:, to:)
    expect(to.work_package_custom_field_ids).to match_array(from.work_package_custom_field_ids)
  end

  def expect_work_package_types_copied(from:, to:)
    expect(to.type_ids).to match_array(from.type_ids)
  end

  def expect_enabled_modules_copied(from:, to:)
    expect(to.enabled_module_names).to match_array(from.enabled_module_names)
  end

  def expect_public_state_copied(from:, to:)
    expect(to.public).to eq(from.public)
  end

  def expect_description_copied(from:, to:)
    expect(to.description).to eq(from.description)
  end

  def expect_status_copied(from:, to:)
    expect(to.status.explanation).to eq(from.status.explanation)
    expect(to.status.code).to eq(from.status.code)
  end

  def expect_members_role_in_project(project_identifier:, role_name:, members: [])
    project = expect_project_present(project_identifier)
    role = expect_project_role_present(role_name)

    expect(role.members.where(project_id: project.id).map(&:user_id)).to include(*members.map(&:id))
  end

  def expect_project_present(project_identifier)
    project = Project.find_by(identifier: project_identifier)

    expect(project).to be_present

    project
  end

  def expect_project_role_present(role_name)
    role = Role.find_by(name: role_name)

    expect(role).to be_present
    expect(role.type).to eq("Role")

    role
  end

  def expect_global_role_with_members(role_name:, members: [])
    role = expect_global_role_present(role_name)

    expect(role.principal_roles.map(&:principal_id)).to include(*members.map(&:id))
  end

  def expect_global_role_present(role_name)
    role = Role.find_by(name: role_name)

    expect(role).to be_present
    expect(role.type).to eq("GlobalRole")

    role
  end

  def expect_group_with_members(groupname:, members: [])
    group = Group.find_by(groupname: groupname)

    expect(group).to be_present

    expect(group.users).to include(*members)

    group
  end

  def expect_non_matching_user_attributes(username:, **kwargs)
    user = expect_user_present(username)

    user_attributes = user.slice(*kwargs.keys)
    expect(user_attributes.symbolize_keys).not_to eq(kwargs)
  end

  def expect_user(username:, **kwargs)
    user = expect_user_present(username)

    user_attributes = user.slice(*kwargs.keys)
    expect(user_attributes.symbolize_keys).to eq(kwargs)

    user
  end

  def expect_user_present(username)
    user = User.find_by(login: username)

    expect(user).to be_present

    user
  end

  def expect_successful_notification
    expect(page).to have_selector('.flash.notice',
                                  text: "The import has been started, you will receive an email once the import is done.")
  end

  def perform_import(file:, authentication_by:, identity_url_prefix: nil, create_non_existing: true)
    select_csv(file)

    select authentication_by, from: "authentication_method_select"

    if authentication_by == "Identity URL"
      fill_in 'identity_url_prefix_textfield', with: identity_url_prefix
    end

    find(:css, "#create_non_existing_checkbox").set(create_non_existing)

    click_button 'Import'

    perform_enqueued_jobs
  end

  def expect_missing_header_errors(columns)
    errors = []

    columns.each do |column|
      errors << "The chosen CSV doesn't contain the '#{column}' column in the header."
    end

    expect_error_flash(errors)
  end

  def expect_error_flash(errors)
    expect(page).to have_selector('.flash.error',
                                  text: errors.join("\n"))
  end

  def expect_top_menu_item(item, present: true)
    page.find('#account-nav-right .last-child').click

    within '#user-menu' do
      if present
        expect(page).to have_link(item)
      else
        expect(page).not_to have_link(item)
      end
    end
  end

  def select_csv(path)
    attach_file('csv_file_input', path)
  end

  def expect_user_invited_mail(mail_address)
    mail = get_mail("Your OpenProject account activation")

    expect(mail).to be_present
    expect_mail_receiver(mail: mail, receiver: mail_address)
  end

  def expect_successful_import_mail(users: 0, groups: 0, roles: 0, projects: 0, errors: ["None"])
    statistics = { "users" => users,
                   "groups" => groups,
                   "roles" => roles,
                   "projects" => projects }

    mail = get_mail("User import completed")

    expect(mail).to be_present

    expect_mail_receiver(mail: mail, receiver: current_user.mail)

    expect_mail_statistics(mail: mail, statistics: statistics)
    expect_mail_errors(mail: mail, error_messages: errors)
  end

  def get_mail(subject)
    mail_found = nil

    ActionMailer::Base.deliveries.each do |mail|
      if mail.subject == subject
        mail_found = mail
      end
    end

    mail_found
  end

  def expect_mail_receiver(mail:, receiver:)
    expect(mail.to).to match_array([receiver])
  end

  def expect_mails_delivered(number)
    expect(ActionMailer::Base.deliveries.count).to eql(number)
  end

  def expect_mail_statistics(mail:, statistics:)
    statistics.each do |key, value|
      expect(mail.html_part.body).to match(/#{key}.*#{value}/)
    end
  end

  def expect_mail_errors(mail:, error_messages: [])
    error_messages.each do |error|
      expect(mail.html_part.body).to include(CGI.escapeHTML(error))
    end
  end
end
