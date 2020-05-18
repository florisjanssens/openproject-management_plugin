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

shared_examples_for 'principal_role contract' do
  let(:current_user) { FactoryBot.build_stubbed(:admin) }
  let(:principal_role_principal) { FactoryBot.build_stubbed(:user) }
  let(:principal_role_role) { FactoryBot.build_stubbed(:global_role) }

  def expect_valid(valid, symbols = {})
    expect(contract.validate).to eq(valid)

    symbols.each do |key, arr|
      expect(contract.errors.symbols_for(key)).to match_array arr
    end
  end

  shared_examples 'is valid' do
    it 'is valid' do
      expect_valid(true)
    end
  end

  # Check the validations
  describe 'validation' do
    it_behaves_like 'is valid'

    # If the user isn't an admin, the contract is epected to be invalid
    context 'if the user is not an administrator' do
      let(:current_user) { FactoryBot.build_stubbed(:user) }
      it 'is invalid' do
        expect_valid(false, base: %i(error_unauthorized))
      end
    end

    context 'if the role is nil' do
      let(:principal_role_role) { nil }

      it 'is invalid' do
        expect_valid(false, role: %i(blank))
      end
    end

    context 'if the principal is nil' do
      let(:principal_role_principal) { nil }

      it 'is invalid' do
        expect_valid(false, principal: %i(blank))
      end
    end
  end
end
