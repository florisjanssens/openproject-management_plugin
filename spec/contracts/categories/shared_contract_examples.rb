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

shared_examples_for 'category contract' do
  # Defines a "memoized" helper method
  # using current_user will call the method.
  # The method creates a test fixture of a User who is an admin
  let(:current_user) do
    u = FactoryBot.build_stubbed(:user)
    allow(u)
      .to receive(:allowed_to?)
      .and_return(false)

    permissions.each do |permission|
      allow(u)
        .to receive(:allowed_to?)
        .with(permission, category_project)
        .and_return(true)
    end

    u
  end

  let(:category_name) { 'category name' }
  let(:category_project) { FactoryBot.build_stubbed(:project) }
  let(:permissions) { [:manage_categories] }

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

  shared_examples 'is valid' do
    it 'is valid' do
      expect_valid(true)
    end
  end

  # Check the validations
  describe 'validation' do
    # Basically includes the shared 'is valid' example defined above
    # This example just checks that when the validation is valid, the contract is also valid
    it_behaves_like 'is valid'

    context 'if the user has no permission to manage categories for the project' do
      let(:permissions) { [] }

      it 'is invalid' do
        expect_valid(false, base: %i(error_unauthorized))
      end
    end

    context 'if the project is nil' do
      let(:category_project) { nil }

      it 'is invalid' do
        expect_valid(false, project: %i(blank))
      end
    end

    context 'if the name is nil' do
      let(:category_name) { nil }

      it 'is invalid' do
        expect_valid(false, name: %i(blank))
      end
    end
  end

  describe 'assigned_to' do
    let(:assignee) { FactoryBot.build_stubbed(:user) }
    let(:assignee_members) { double('assignee_members') }

    before do
      allow(category)
        .to receive(:project)
        .and_return(category_project)

      allow(category_project)
        .to receive(:principals)
        .and_return(assignee_members)

      allow(assignee_members)
        .to receive(:map)
        .and_return(assignee_members)

      allow(assignee_members)
        .to receive(:include?)
        .with(assignee.id)
        .and_return true

      category.assigned_to = assignee
    end

    context 'if the assignee is a valid assignee' do
      it_behaves_like 'is valid'
    end

    context 'if the assignee is not a valid assignee' do
      before do
        allow(assignee_members)
          .to receive(:include?)
          .with(assignee.id)
          .and_return false
      end

      it 'is invalid' do
        contract.validate

        message = I18n.t('error_must_be_project_member')
        expect(contract.errors[:assigned_to_id]).to match_array [message]
      end
    end
  end
end
