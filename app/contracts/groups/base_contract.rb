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

module Groups
  class BaseContract < ::ModelContract
    include AssignableValuesContract

    delegate :new_record?,
             to: :model

    attribute :groupname
    attribute :lastname
    attribute :type

    def self.model
      Group
    end

    # Extend the validate method of the ModelContract with extra validations
    # Note that the ModelContract runs validations like attribute validations or
    # model validations and adds the errors together with the contract errors.
    def validate
      user_allowed_to_manage

      super
    end

    private

    # Only admins can manage groups
    def user_allowed_to_manage
      unless user.admin?
        errors.add :base, :error_unauthorized
      end
    end
  end
end
