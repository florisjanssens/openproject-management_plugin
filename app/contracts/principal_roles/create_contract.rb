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
  class CreateContract < BaseContract
    attribute :role do
      role_grantable
      # If the role was invalid, set it to some dummy role
      # This is necessary because the core PrincipalRole model does a validation that only
      # works on roles of the GlobalRole type. If the role was invalid, the core
      # PrincipalRole model would throw an exception. The model itself could handle the
      # validation much better. This could be monkey patched but supplying simple dummy
      # data is much more straightforward
      model.role = GlobalRole.new if
                     model.role.nil? ||
                     errors[:role].include?("cannot be given to the principal or isn't global.")
    end

    attribute :principal do
      principal_assignable
    end

    private

    # Check if the principal is an assignable principal.
    # This means that the principal can't be one of the builtin principals or a locked one
    def principal_assignable
      return if model.principal.nil?

      if model.principal.builtin? || model.principal.status == Principal::STATUSES[:locked]
        errors.add :principal, "cannot be assigned to a global role."
      end
    end

    # Check if the role is actually a grantable role
    # This means it should be a global role as PrincipalRole is made to
    # assign principals to global roles. It also means that the role can't be
    # one of the builtin roles.
    def role_grantable
      return if model.role.nil?

      unless model.role.builtin == Role::NON_BUILTIN && model.role.class == GlobalRole
        errors.add :role, "cannot be given to the principal or isn't global."
      end
    end
  end
end
