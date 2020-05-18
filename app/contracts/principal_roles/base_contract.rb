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

module PrincipalRoles
  class BaseContract < ::ModelContract
    include AssignableValuesContract

    delegate :role_id,
             :principal_id,
             :new_record?,
             to: :model

    def self.model
      PrincipalRole
    end

    # Extend the validate method of the ModelContract with extra validations
    # Note that the ModelContract runs validations like attribute validations or
    # model validations and adds the errors together with the contract errors.
    def validate
      user_allowed_to_manage
      validate_role_is_set
      validate_principal_is_set
      super
    end

    private

    # Only admins can edit assignment to global roles
    def user_allowed_to_manage
      unless user.admin?
        errors.add :base, :error_unauthorized
      end
    end

    # Check if a role was given (this would also give an error
    # if only a role_id was passed and a role with the id doesn't exist)
    def validate_role_is_set
      errors.add :role, :blank if model.role.nil?
    end

    # Check if a principal was given (this would also give an error
    # if only a principal_id was passed and a principal with the id doesn't exist)
    def validate_principal_is_set
      errors.add :principal, :blank if model.principal.nil?
    end
  end
end
