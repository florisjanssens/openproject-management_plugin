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

describe ProjectsController, type: :controller do
  let(:current_user) do
    FactoryBot.create(:user, member_in_project: project,
                             member_through_role: role)
  end
  let(:role) { FactoryBot.create(:role, permissions: permissions) }
  let(:permissions) { [] }
  let(:selected_settings) { [] }
  let!(:project) { FactoryBot.create(:project) }
  let!(:subproject) { FactoryBot.create(:project, parent_id: project.id) }

  def copy_settings(project, settings)
    post :bulk_copy_settings, params: { id: project.id, selected_settings: settings }
  end

  before do
    login_as(current_user)
  end

  describe '#bulk_copy_settings' do
    shared_examples_for 'valid bulk copy response' do
      it 'redirects back to the bulk copy settings page' do
        copy_settings(project, selected_settings)
        expect(response).to redirect_to(controller: 'project_settings/bulk_setter', action: 'show', id: project.identifier)
      end

      it 'is successful' do
        expect(response).to be_successful
        copy_settings(project, selected_settings)
      end

      it 'returns 200 OK' do
        expect(response.code).to eq('200')
        copy_settings(project, selected_settings)
      end
    end

    context 'as an authorized user' do
      let(:permissions) { [:edit_project] }
      let(:selected_settings) { [] }

      context 'without any settings selected' do
        it 'does not schedule a copy project settings job' do
          expect(BulkCopyProjectSettingsJob).not_to receive(:perform_later)
          copy_settings(project, [])
        end

        it 'shows an error indicating no settings were chosen' do
          copy_settings(project, [])
          expect(flash[:error]).to eq("No settings were chosen to be copied.")
        end

        include_examples 'valid bulk copy response'
      end

      context 'with valid settings selected' do
        let(:selected_settings) do
          {
            "attributes" => ["description", "status", "public", "enabled_module_names",
                             "type_ids", "work_package_custom_field_ids"],
            "categories" => ["new_categories"],
            "versions" => ["start_date", "effective_date", "description", "status", "new_versions"]
          }
        end

        it 'schedules a copy project settings job' do
          expect(BulkCopyProjectSettingsJob).to receive(:perform_later).and_call_original
          copy_settings(project, selected_settings)
        end

        it 'shows a notification indicating that the copy has been started' do
          copy_settings(project, selected_settings)
          expect(flash[:notice]).to eq("The copy has been started, you will receive an email once this is done.")
        end

        include_examples 'valid bulk copy response'
      end
    end

    context 'as an unauthorized user' do
      let(:permissions) { [] }

      before do
        copy_settings(project, [])
      end

      it 'is not successful' do
        expect(response).not_to be_successful
      end

      it 'returns 403 Forbidden' do
        expect(response.status).to eq(403)
      end

      it 'renders the error page' do
        expect(response).to render_template('common/error')
      end
    end
  end
end
