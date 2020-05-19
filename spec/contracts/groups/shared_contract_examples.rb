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

shared_examples_for 'group contract' do
  # Defines a "memoized" helper method
  # using current_user will call the method.
  # The method creates a test fixture of a User who is an admin
  let(:current_user) { FactoryBot.build_stubbed(:admin) }
  let(:group_groupname) { 'Group name' }

  # This is just a self-defined method so the code within it doesn't have
  # to be repeated multiple times.
  # It can be called with an expected result as the parameter (true or false)
  # after which the example will succeed if the result of validating the contract
  # in this case is the same result as the parameter and vice versa
  # If symbols are given as a parameter, they are basically compared to
  # the errors of the contract creation (if it failed, it has errors)
  # The given value should match the value of the contract errors for the same key.
  def expect_valid(valid, symbols = {})
    expect(contract.validate).to eq(valid)

    symbols.each do |key, arr|
      expect(contract.errors.symbols_for(key)).to match_array arr
    end
  end

  # Check the validations
  describe 'validation' do
    shared_examples 'is valid' do
      it 'is valid' do
        expect_valid(true)
      end
    end

    # Basically includes the shared 'is valid' example defined above
    # This example just checks that when the validation is valid, the contract is also valid
    it_behaves_like 'is valid'

    # If the user isn't an admin, the contract is epected to be invalid
    context 'if the user is not an administrator' do
      let(:current_user) { FactoryBot.build_stubbed(:user) }
      it 'is invalid' do
        expect_valid(false, base: %i(error_unauthorized))
      end
    end

    # If the name of the group is nil, the contract is expected to be invalid
    context 'if the name is nil' do
      before do
        group.groupname = nil
      end

      it 'is invalid' do
        expect_valid(false, groupname: %i(blank))
      end
    end
  end
end
