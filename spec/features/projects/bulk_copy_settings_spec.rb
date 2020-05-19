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

feature 'Bulk copy project settings', type: :feature, js: true do
  let!(:current_user) { FactoryBot.create(:user) }
  let!(:parent_role) { FactoryBot.create(:role, permissions: parent_permissions) }
  let(:parent_permissions) { %i[edit_project manage_types manage_versions manage_categories select_project_modules] }
  let!(:sub_role) { FactoryBot.create(:role, permissions: sub_permissions) }
  let(:sub_permissions) { %i[edit_project manage_types manage_versions manage_categories select_project_modules] }
  let!(:project_status) { FactoryBot.create(:project_status) }
  let!(:project_public) { true }
  let!(:project_description) { "The best project ever." }
  let!(:project_modules) { OpenProject::AccessControl.available_project_modules }
  let!(:custom_field_1) { FactoryBot.create(:work_package_custom_field) }
  let!(:custom_field_2) { FactoryBot.create(:work_package_custom_field) }
  let!(:category_1) { FactoryBot.create(:category, project: project) }
  let!(:category_2) { FactoryBot.create(:category, project: project) }
  let!(:version1) do
    FactoryBot.create(:version,
                      project: project,
                      description: "Something descriptive",
                      start_date: '2001-03-25',
                      effective_date: '2001-05-26',
                      status: "closed")
  end
  let!(:version2) do
    FactoryBot.create(:version,
                      project: project,
                      description: "Something else descriptive",
                      start_date: '2002-03-25',
                      effective_date: '2002-05-26')
  end
  let!(:version3) do
    FactoryBot.create(:version,
                      project: project,
                      status: "closed")
  end
  let!(:version4) do
    FactoryBot.create(:version,
                      project: project,
                      sharing: "descendants")
  end
  let!(:project) do
    FactoryBot.create(:project_with_types,
                      description: project_description,
                      public: project_public,
                      status: project_status,
                      enabled_module_names: project_modules,
                      work_package_custom_field_ids: [custom_field_1.id, custom_field_2.id])
  end

  let!(:project_member) do
    FactoryBot.create(:member,
                      user: current_user,
                      project: project,
                      roles: [parent_role])
  end

  let!(:subproject_member) do
    FactoryBot.create(:member,
                      user: current_user,
                      project: subproject,
                      roles: [sub_role])
  end

  let!(:category_3) { FactoryBot.create(:category, name: category_1.name, project: subproject) }
  let!(:category_4) { FactoryBot.create(:category, name: "something unique", project: subproject) }
  let!(:version5) { FactoryBot.create(:version, project: subproject, name: version1.name) }
  let!(:version6) { FactoryBot.create(:version, project: subproject, name: "Something unique.") }

  let!(:subproject) do
    FactoryBot.create(:project,
                      parent_id: project.id,
                      description: "",
                      public: false,
                      status: nil,
                      enabled_module_names: ["work_package_tracking"],
                      no_types: true)
  end

  before do
    login_as current_user

    # Clear all jobs which may be left from previous scenarios before each scenario
    clear_enqueued_jobs
    clear_performed_jobs

    visit settings_bulk_setter_path(project)
  end

  context 'as a user without permissions' do
    let(:parent_permissions) { [:view_project] }
    scenario 'navigating to the bulk setting copy page shows the unauthorized message' do
      expect(page).to have_selector('.notification-box--content', text: "[Error 403]")
    end
  end

  context 'as a user with at least once but not all permissions in the parent' do
    let(:parent_permissions) { %i[manage_types manage_versions manage_categories select_project_modules] }
    scenario 'only allow the user to select settings to which the user has permission' do
      expect(page).to have_selector('.not-allowed_error',
                                    text: "You don't have permission to edit project information.")
      expect(page).to have_selector('.not-allowed_error',
                                    text: "You don't have permission to edit the modules of this project.")
      expect(page).to have_selector('.not-allowed_error',
                                    text: "You don't have permission to edit the work package types of this project.")
      expect(page).to have_selector('.not-allowed_error',
                                    text: "You don't have permission to edit the enabled/disabled custom fields of this project.")
      expect(page).not_to have_selector('.not-allowed_error',
                                        text: "You don't have permission to manage categories of this project.")
      expect(page).not_to have_selector('.not-allowed_error',
                                        text: "You don't have permission to manage versions of this project.")
    end
  end

  context 'as a user with full permissions in the parent' do
    context 'without a subproject' do
      let!(:subproject) { FactoryBot.create(:project) }

      scenario 'the bulk copy settings button is invisible' do
        visit project_path(project)

        expect(page).not_to have_selector('.menu-item--title', text: "Bulk copy settings")
      end

      scenario 'navigating to the bulk setting copy page shows the unauthorized message' do
        expect(page).to have_selector('.notification-box--content', text: "[Error 403]")
      end
    end

    context 'and a lacking permission in the subproject' do
      let(:sub_permissions) { %i[manage_types manage_versions manage_categories select_project_modules] }

      scenario 'copying settings of a parent to a subproject only' \
               'copies settings which the user is allowed to copy in the subproject' do
        select_settings

        start_copy

        expect_successful_notification

        expect_description_copied(to: subproject, copied: false)

        expect_status_copied(to: subproject, copied: false)

        expect_public_state_copied(to: subproject, copied: false)

        expect_enabled_modules_copied(to: subproject, copied: false)

        expect_work_package_types_copied(to: subproject, copied: false)

        expect_custom_fields_copied(to: subproject, copied: false)

        expect_categories_to_exist(in_project: subproject,
                                   categories: [category_1, category_2, category_4])

        expect_versions_to_exist(in_project: subproject, versions: [version1, version2, version6])
        expect_versions_not_to_exist(in_project: subproject, versions: [version3, version4])

        expect_version_attributes_copied(to: subproject, from_versions: [version1, version2])

        error_msg = "While copying attributes to #{subproject.name}: You don't have " \
                     "permission to edit the attributes of this project."
        expect_mail(subject: "Bulk copying settings of #{project.name} finished",
                    error_messages: [error_msg])
      end
    end

    context 'and full permissions on multiple subprojects' do
      let!(:subproject2) do
        FactoryBot.create(:project,
                          parent_id: project.id,
                          description: "",
                          public: false,
                          status: nil,
                          enabled_module_names: ["work_package_tracking"],
                          no_types: true)
      end

      let!(:subproject2_member) do
        FactoryBot.create(:member,
                          user: current_user,
                          project: subproject2,
                          roles: [sub_role])
      end

      let!(:category_5) { FactoryBot.create(:category, name: category_1.name, project: subproject2) }
      let!(:category_6) { FactoryBot.create(:category, name: "something unique", project: subproject2) }
      let!(:version7) { FactoryBot.create(:version, project: subproject2, name: version1.name) }
      let!(:version8) { FactoryBot.create(:version, project: subproject2, name: "Something unique.") }

      scenario 'the bulk copy settings button is visible' do
        visit settings_generic_project_path(project)

        expect(page).to have_selector('.menu-item--title', text: "Bulk copy settings")
      end

      scenario 'copying settings of a parent copies the settings to all subprojects' do
        select_settings

        start_copy

        subproject2.reload

        expect_successful_notification

        [subproject, subproject2].each do |sub|
          expect_description_copied(to: sub, copied: true)

          expect_status_copied(to: sub, copied: true)

          expect_public_state_copied(to: sub, copied: true)

          expect_enabled_modules_copied(to: sub, copied: true)

          expect_work_package_types_copied(to: sub, copied: true)

          expect_custom_fields_copied(to: sub, copied: true)

          expect_categories_to_exist(in_project: sub,
                                     categories: [category_1, category_2, category_4])

          expect_versions_to_exist(in_project: sub, versions: [version1, version2, version6])
          expect_versions_not_to_exist(in_project: sub, versions: [version3, version4])

          expect_version_attributes_copied(to: sub, from_versions: [version1, version2])
        end

        expect_mail(subject: "Bulk copying settings of #{project.name} finished")
      end
    end

    context 'and full permissions on the subproject' do
      context 'which is archived' do
        let!(:subproject) do
          FactoryBot.create(:project,
                            parent_id: project.id,
                            active: false,
                            description: "",
                            public: false,
                            status: nil,
                            enabled_module_names: ["work_package_tracking"],
                            no_types: true)
        end

        scenario 'copying settings of a parent to a subproject ignores archived subprojects' do
          select_settings

          start_copy

          expect_successful_notification

          expect_description_copied(to: subproject, copied: false)

          expect_status_copied(to: subproject, copied: false)

          expect_public_state_copied(to: subproject, copied: false)

          expect_enabled_modules_copied(to: subproject, copied: false)

          expect_work_package_types_copied(to: subproject, copied: false)

          expect_custom_fields_copied(to: subproject, copied: false)

          expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
          expect_categories_to_exist(in_project: subproject,
                                     categories: [category_3, category_4])

          expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
          expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
          expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

          expect_mail(subject: "Bulk copying settings of #{project.name} finished")
        end
      end

      scenario 'show the no settings selected error when starting a bulk copy without selecting settings' do
        start_copy

        expect(page).to have_selector('.none-selected-error', text: "You must select at least one setting to copy!")
      end

      scenario 'the parent project dissapears while copying settings' do
        select_settings

        click_button 'Apply'

        project.destroy

        perform_enqueued_jobs

        expect_mail(subject: "Bulk copying settings failed", error_messages: [])
      end

      scenario 'copying the description of the parent to the subproject' do
        select_settings(only: ["Description"])

        start_copy

        expect_successful_notification

        expect_description_copied(to: subproject, copied: true)

        expect_status_copied(to: subproject, copied: false)

        expect_public_state_copied(to: subproject, copied: false)

        expect_enabled_modules_copied(to: subproject, copied: false)

        expect_work_package_types_copied(to: subproject, copied: false)

        expect_custom_fields_copied(to: subproject, copied: false)

        expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
        expect_categories_to_exist(in_project: subproject,
                                   categories: [category_3, category_4])

        expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
        expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
        expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

        expect_mail(subject: "Bulk copying settings of #{project.name} finished")
      end
    end

    scenario 'copying the status of the parent to the subproject' do
      select_settings(only: ["Project status"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: true)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the public state of the parent to the subproject' do
      select_settings(only: ["Public state"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: true)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the enabled modules of the parent to the subproject' do
      select_settings(only: ["Modules"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: true)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the enabled work package types of the parent to the subproject' do
      select_settings(only: ["Work package types"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: true)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the enabled custom fields of the parent to the subproject' do
      select_settings(only: ["Custom fields"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: true)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying categories of the parent to the subproject for which these categories did not exist' do
      select_settings(only: ["New categories"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_2, category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying non-shared/non-closed versions of the parent to the subproject for which these versions did not exist' do
      select_settings(only: ["New versions"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version2, version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version3, version4])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying dates of versions of the parent to matching versions of the subproject' do
      select_settings(only: ["Version start dates", "Version end dates"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_copied(to: subproject, from_versions: [version1], attributes: ["dates"])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1], attributes: ["status", "description"])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the description of versions of the parent to matching versions of the subproject' do
      select_settings(only: ["Version descriptions"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_copied(to: subproject, from_versions: [version1], attributes: ["description"])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1], attributes: ["dates", "status"])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying the status of versions of the parent to matching versions of the subproject' do
      select_settings(only: ["Version statuses"])

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: false)

      expect_status_copied(to: subproject, copied: false)

      expect_public_state_copied(to: subproject, copied: false)

      expect_enabled_modules_copied(to: subproject, copied: false)

      expect_work_package_types_copied(to: subproject, copied: false)

      expect_custom_fields_copied(to: subproject, copied: false)

      expect_categories_not_to_exist(in_project: subproject, categories: [category_2])
      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_3, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version5, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version2, version3, version4])
      expect_version_attributes_copied(to: subproject, from_versions: [version1], attributes: ["status"])
      expect_version_attributes_not_copied(to: subproject, from_versions: [version1], attributes: ["description", "dates"])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end

    scenario 'copying all settings of the parent to the subproject at once' do
      select_settings

      start_copy

      expect_successful_notification

      expect_description_copied(to: subproject, copied: true)

      expect_status_copied(to: subproject, copied: true)

      expect_public_state_copied(to: subproject, copied: true)

      expect_enabled_modules_copied(to: subproject, copied: true)

      expect_work_package_types_copied(to: subproject, copied: true)

      expect_custom_fields_copied(to: subproject, copied: true)

      expect_categories_to_exist(in_project: subproject,
                                 categories: [category_1, category_2, category_4])

      expect_versions_to_exist(in_project: subproject, versions: [version1, version2, version6])
      expect_versions_not_to_exist(in_project: subproject, versions: [version3, version4])

      expect_version_attributes_copied(to: subproject, from_versions: [version1, version2])

      expect_mail(subject: "Bulk copying settings of #{project.name} finished")
    end
  end

  def expect_mail(subject:, error_messages: ["None"])
    # User should receive a mail indicating the copy is done with or without errors
    expect_mails_delivered(1)

    mail = get_last_mail

    expect_mail_headers(mail: mail, subject: subject, receivers: [current_user.mail])

    expect_mail_errors(mail: mail, error_messages: error_messages)
  end

  def get_last_mail
    ActionMailer::Base.deliveries.last
  end

  def expect_mail_headers(mail:, subject:, receivers:)
    expect(mail.subject)
      .to eql(subject)

    expect(mail.to)
      .to match_array(receivers)
  end

  def expect_mails_delivered(number)
    expect(ActionMailer::Base.deliveries.count).to eql(number)
  end

  def expect_mail_errors(mail:, error_messages: [])
    error_messages.each do |error|
      expect(mail.html_part.body).to include(CGI.escapeHTML(error))
    end
  end

  def select_settings(only: [])
    if only.empty?
      # Select all the settings
      all('input[type=checkbox]').each do |checkbox|
        checkbox.click unless checkbox.checked?
      end
    else
      only.each do |setting|
        check setting
      end
    end
  end

  def start_copy
    click_button 'Apply'

    perform_enqueued_jobs
    subproject.reload
  end

  def expect_successful_notification
    expect(page).to have_selector('.flash.notice',
                                  text: "The copy has been started, you will receive an email once this is done.")
  end

  def expect_version_attributes_copied(to:, from_versions:, attributes: ["dates", "status", "description"])
    from_versions.each do |version|
      sub_version = to.versions.find_by(name: version.name)

      expect_same_version_dates(version1: version, version2: sub_version) if attributes.include?("dates")
      expect_same_version_description(version1: version, version2: sub_version) if attributes.include?("description")
      expect_same_version_status(version1: version, version2: sub_version) if attributes.include?("status")
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

  def expect_different_version_status(version1:, version2:)
    expect(version2.status).not_to eq(version1.status)
  end

  def expect_different_version_description(version1:, version2:)
    expect(version2.description).not_to eq(version1.description)
  end

  def expect_different_version_dates(version1:, version2:)
    expect(version2.start_date).not_to eq(version1.start_date)
    expect(version2.effective_date).not_to eq(version1.effective_date)
  end

  def expect_version_attributes_not_copied(to:, from_versions:, attributes: ["dates", "status", "description"])
    from_versions.each do |version|
      sub_version = to.versions.find_by(name: version.name)

      expect_different_version_dates(version1: version, version2: sub_version) if attributes.include?("dates")
      expect_different_version_description(version1: version, version2: sub_version) if attributes.include?("description")
      expect_different_version_status(version1: version, version2: sub_version) if attributes.include?("status")
    end
  end

  def expect_versions_to_exist(in_project:, versions:)
    versions.each do |version|
      expect(in_project.versions.find_by(name: version.name)).to be_present
    end
  end

  def expect_versions_not_to_exist(in_project:, versions:)
    versions.each do |version|
      expect(in_project.versions.find_by(name: version.name)).not_to be_present
    end
  end

  def expect_categories_not_to_exist(in_project:, categories:)
    categories.each do |category|
      expect(in_project.categories.find_by(name: category.name)).not_to be_present
    end
  end

  def expect_categories_to_exist(in_project:, categories:)
    categories.each do |category|
      expect(in_project.categories.find_by(name: category.name)).to be_present
    end
  end

  def expect_custom_fields_copied(to:, copied: true)
    if copied
      expect(to.work_package_custom_field_ids).to match_array(project.work_package_custom_field_ids)
    else
      expect(to.work_package_custom_field_ids).not_to match_array(project.work_package_custom_field_ids)
    end
  end

  def expect_work_package_types_copied(to:, copied: true)
    if copied
      expect(to.type_ids).to match_array(project.type_ids)
    else
      expect(to.type_ids).not_to match_array(project.type_ids)
    end
  end

  def expect_enabled_modules_copied(to:, copied: true)
    if copied
      expect(to.enabled_module_names).to match_array(project.enabled_module_names)
    else
      expect(to.enabled_module_names).not_to match_array(project.enabled_module_names)
    end
  end

  def expect_public_state_copied(to:, copied: true)
    if copied
      expect(to.public).to eq(project.public)
    else
      expect(to.public).not_to eq(project.public)
    end
  end

  def expect_description_copied(to:, copied: true)
    if copied
      expect(to.description).to eq(project.description)
    else
      expect(to.description).not_to eq(project.description)
    end
  end

  def expect_status_copied(to:, copied: true)
    if copied
      expect_same_status(project1: project, project2: to)
    elsif to.status.present?
      expect_empty_status(in_project: to)
    end
  end

  def expect_same_status(project1:, project2:)
    expect(project2.status.explanation).to eq(project1.status.explanation)
    expect(project2.status.code).to eq(project1.status.code)
  end

  def expect_empty_status(in_project:)
    expect(in_project.status.explanation).to be_nil
    expect(in_project.status.code).to be_nil
  end
end
