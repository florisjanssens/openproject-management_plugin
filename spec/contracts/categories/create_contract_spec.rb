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

describe Categories::CreateContract do
  # NOTE: this will start the examples in ./shared_contract_examples.rb
  # It uses the :category and :contract we define here
  it_behaves_like 'category contract' do
    # Defines a "memoized" helper method.
    # category can now be used in the continuation of this code
    # to call the method. The resulting value will be cached
    # and used in subsequent calls.
    # The result of the method is basically a test fixture of Category
    # as defined in core/spec/factories/category_factory.rb
    let(:category) do
      Category.new(name: category_name,
                   project: category_project,
                   assigned_to: nil)
    end
    # Subject is a special variable that refers to the object being tested
    # (in this case the Categories::CreateContract). Basically lets
    # RSpec call methods to the object without referring to it explicitly.
    # The method basically creates the contract with the category fixture
    # and a current user as parameters (current_user is defined differently
    # inside different contexes)
    subject(:contract) { described_class.new(category, current_user) }
  end
end
