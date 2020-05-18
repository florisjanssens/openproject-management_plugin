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
require_relative './shared_contract_examples'

describe PrincipalRoles::CreateContract do
  it_behaves_like 'principal_role contract' do
    let(:principal_role) do
      PrincipalRole.new(principal: principal_role_principal,
                        role: principal_role_role)
    end
    subject(:contract) { described_class.new(principal_role, current_user) }

    describe 'validation' do
      # If the user isn't an admin, the contract is epected to be invalid
      context 'if the principal is a builtin principal' do
        let(:principal_role_principal) { FactoryBot.build_stubbed(:system) }

        it 'is invalid' do
          contract.validate
          message = "cannot be assigned to a global role."
          expect(contract.errors[:principal]).to match_array [message]
        end
      end

      context 'if the principal is locked' do
        let(:principal_role_principal) { FactoryBot.build_stubbed(:locked_user) }

        it 'is invalid' do
          contract.validate
          message = "cannot be assigned to a global role."
          expect(contract.errors[:principal]).to match_array [message]
        end
      end

      context 'if the role is a builtin role' do
        before do
          principal_role.role.builtin = 1
        end

        it 'is invalid' do
          contract.validate
          message = "cannot be given to the principal or isn't global."
          expect(contract.errors[:role]).to match_array [message]
        end
      end

      context 'if the role is not global' do
        let(:principal_role_role) { FactoryBot.build_stubbed(:role) }

        it 'is invalid' do
          contract.validate
          message = "cannot be given to the principal or isn't global."
          expect(contract.errors[:role]).to match_array [message]
        end
      end
    end
  end
end
