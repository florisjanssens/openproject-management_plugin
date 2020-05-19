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

describe ProjectSettings::BulkSetterController, type: :controller do
  let!(:project) { FactoryBot.create(:project) }
  let!(:subproject) do
    FactoryBot.create(:project,
                      parent_id: project.id)
  end
  let(:user) do
    FactoryBot.create(:user, member_in_project: project,
                             member_through_role: role)
  end
  let(:role) { FactoryBot.create(:role, permissions: []) }

  before do
    login_as(user)
    get :show, params: { id: project.id }
  end

  describe '#show' do
    context 'with an unauthorized account' do
      let(:role) { FactoryBot.create(:role, permissions: [:view_project]) }

      it { expect(response).not_to be_successful }
      it { expect(response.status).to eq(403) }
      it { expect(response).to render_template('common/error') }
    end

    context 'with an authorized account' do
      let(:role) { FactoryBot.create(:role, permissions: [:edit_project]) }

      context 'when the project has children' do
        it { expect(response).to be_successful }
        it { expect(response.status).to eq(200) }
        it { expect(response).to render_template('project_settings/bulk_setter') }
      end

      context 'when the project has no children' do
        let!(:subproject) { nil }

        it { expect(response).not_to be_successful }
        it { expect(response.status).to eq(403) }
        it { expect(response).to render_template 'common/error' }
      end
    end
  end
end
