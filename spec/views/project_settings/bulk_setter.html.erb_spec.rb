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

describe 'project_settings/bulk_setter', type: :view do
  let(:user) { FactoryBot.build_stubbed :user }
  let!(:project) { FactoryBot.create(:project) }
  let!(:subproject) do
    FactoryBot.create(:project,
                      parent_id: project.id)
  end

  let(:permissions) do
    %i(edit_project
       select_project_modules
       manage_types
       manage_categories
       manage_versions)
  end

  before do
    # Mock the id parameter of the route
    controller.request.path_parameters[:id] = project.id
    assign(:project, project)

    # Disable every permission first
    allow(User.current).to receive(:allowed_to?).and_return(false)

    # Then enable the requested permissions
    permissions.each do |permission|
      allow(User.current).to receive(:allowed_to?).with(permission, project).and_return(true)
    end

    render
  end

  subject { rendered }

  def expect_label(present, text)
    if present
      is_expected.to have_selector('.form--label', text: text)
    else
      is_expected.to have_no_selector('.form--label', text: text)
    end
  end

  def expect_permission_error(present, permission_id)
    if present
      is_expected.to have_selector("#{permission_id} .not-allowed_error")
    else
      is_expected.to have_no_selector("#{permission_id} .not-allowed_error")
    end
  end

  context 'when the user has no permissions' do
    let(:permissions) { [] }

    it 'shows no checkboxes' do
      expect_label(false, 'Description')
      expect_label(false, 'Project status')
      expect_label(false, 'Public state')
      expect_label(false, 'Modules')
      expect_label(false, 'Work package types')
      expect_label(false, 'Custom fields')
      expect_label(false, 'New categories')
      expect_label(false, 'Version start dates')
      expect_label(false, 'Version end dates')
      expect_label(false, 'Version descriptions')
      expect_label(false, 'Version statuses')
      expect_label(false, 'New versions')
    end

    it 'shows the no permissions error for all settings' do
      expect_permission_error(true, '#project_information')
      expect_permission_error(true, '#project_modules')
      expect_permission_error(true, '#project_work_package_types')
      expect_permission_error(true, '#project_custom_fields')
      expect_permission_error(true, '#project_categories')
      expect_permission_error(true, '#project_versions')
    end
  end

  context 'when the user has all permissions' do
    it 'shows checkboxes for all settings' do
      expect_label(true, 'Description')
      expect_label(true, 'Project status')
      expect_label(true, 'Public state')
      expect_label(true, 'Modules')
      expect_label(true, 'Work package types')
      expect_label(true, 'Custom fields')
      expect_label(true, 'New categories')
      expect_label(true, 'Version start dates')
      expect_label(true, 'Version end dates')
      expect_label(true, 'Version descriptions')
      expect_label(true, 'Version statuses')
      expect_label(true, 'New versions')
    end

    it 'does not show any permission error' do
      expect_permission_error(false, '#project_information')
      expect_permission_error(false, '#project_modules')
      expect_permission_error(false, '#project_work_package_types')
      expect_permission_error(false, '#project_custom_fields')
      expect_permission_error(false, '#project_categories')
      expect_permission_error(false, '#project_versions')
    end
  end

  context 'when the user has all permissions except permission to edit projects' do
    let(:permissions) do
      %i(select_project_modules
         manage_types
         manage_categories
         manage_versions)
    end

    it 'does not show checkboxes for project information, modules, types and custom fields' do
      expect_label(false, 'Description')
      expect_label(false, 'Project status')
      expect_label(false, 'Public state')
      expect_label(false, 'Modules')
      expect_label(false, 'Work package types')
      expect_label(false, 'Custom fields')
      expect_label(true, 'New categories')
      expect_label(true, 'Version start dates')
      expect_label(true, 'Version end dates')
      expect_label(true, 'Version descriptions')
      expect_label(true, 'Version statuses')
      expect_label(true, 'New versions')
    end

    it 'shows the no permissions error for project information, modules, types and custom fields' do
      expect_permission_error(true, '#project_information')
      expect_permission_error(true, '#project_modules')
      expect_permission_error(true, '#project_work_package_types')
      expect_permission_error(true, '#project_custom_fields')
      expect_permission_error(false, '#project_categories')
      expect_permission_error(false, '#project_versions')
    end
  end

  context 'when the user has all permissions except permission to manage versions' do
    let(:permissions) do
      %i(edit_project
         select_project_modules
         manage_types
         manage_categories)
    end

    it 'does not show checkboxes for project version settings' do
      expect_label(true, 'Description')
      expect_label(true, 'Project status')
      expect_label(true, 'Public state')
      expect_label(true, 'Modules')
      expect_label(true, 'Work package types')
      expect_label(true, 'Custom fields')
      expect_label(true, 'New categories')
      expect_label(false, 'Version start dates')
      expect_label(false, 'Version end dates')
      expect_label(false, 'Version descriptions')
      expect_label(false, 'Version statuses')
      expect_label(false, 'New versions')
    end

    it 'shows the no permissions error for project versions' do
      expect_permission_error(false, '#project_information')
      expect_permission_error(false, '#project_modules')
      expect_permission_error(false, '#project_work_package_types')
      expect_permission_error(false, '#project_custom_fields')
      expect_permission_error(false, '#project_categories')
      expect_permission_error(true, '#project_versions')
    end
  end

  context 'when the user has all permissions except permission to manage categories' do
    let(:permissions) do
      %i(edit_project
         select_project_modules
         manage_types
         manage_versions)
    end

    it 'does not show checkboxes for project category settings' do
      expect_label(true, 'Description')
      expect_label(true, 'Project status')
      expect_label(true, 'Public state')
      expect_label(true, 'Modules')
      expect_label(true, 'Work package types')
      expect_label(true, 'Custom fields')
      expect_label(false, 'New categories')
      expect_label(true, 'Version start dates')
      expect_label(true, 'Version end dates')
      expect_label(true, 'Version descriptions')
      expect_label(true, 'Version statuses')
      expect_label(true, 'New versions')
    end

    it 'shows the no permissions error for project categories' do
      expect_permission_error(false, '#project_information')
      expect_permission_error(false, '#project_modules')
      expect_permission_error(false, '#project_work_package_types')
      expect_permission_error(false, '#project_custom_fields')
      expect_permission_error(true, '#project_categories')
      expect_permission_error(false, '#project_versions')
    end
  end

  context 'when the user has all permissions except permission to manage work package types' do
    let(:permissions) do
      %i(edit_project
         select_project_modules
         manage_categories
         manage_versions)
    end

    it 'does not show checkboxes for project work package types' do
      expect_label(true, 'Description')
      expect_label(true, 'Project status')
      expect_label(true, 'Public state')
      expect_label(true, 'Modules')
      expect_label(false, 'Work package types')
      expect_label(true, 'Custom fields')
      expect_label(true, 'New categories')
      expect_label(true, 'Version start dates')
      expect_label(true, 'Version end dates')
      expect_label(true, 'Version descriptions')
      expect_label(true, 'Version statuses')
      expect_label(true, 'New versions')
    end

    it 'shows the no permissions error for project work package types' do
      expect_permission_error(false, '#project_information')
      expect_permission_error(false, '#project_modules')
      expect_permission_error(true, '#project_work_package_types')
      expect_permission_error(false, '#project_custom_fields')
      expect_permission_error(false, '#project_categories')
      expect_permission_error(false, '#project_versions')
    end
  end

  context 'when the user has all permissions except permission to manage project modules' do
    let(:permissions) do
      %i(edit_project
         manage_types
         manage_categories
         manage_versions)
    end

    it 'does not show checkboxes for project module settings' do
      expect_label(true, 'Description')
      expect_label(true, 'Project status')
      expect_label(true, 'Public state')
      expect_label(false, 'Modules')
      expect_label(true, 'Work package types')
      expect_label(true, 'Custom fields')
      expect_label(true, 'New categories')
      expect_label(true, 'Version start dates')
      expect_label(true, 'Version end dates')
      expect_label(true, 'Version descriptions')
      expect_label(true, 'Version statuses')
      expect_label(true, 'New versions')
    end

    it 'shows the no permissions error for project modules' do
      expect_permission_error(false, '#project_information')
      expect_permission_error(true, '#project_modules')
      expect_permission_error(false, '#project_work_package_types')
      expect_permission_error(false, '#project_custom_fields')
      expect_permission_error(false, '#project_categories')
      expect_permission_error(false, '#project_versions')
    end
  end
end
