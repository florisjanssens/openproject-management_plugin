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

module Categories
  class BaseContract < ::ModelContract
    include AssignableValuesContract

    delegate :project,
             :new_record?,
             to: :model

    # Already validated by the model
    attribute :name

    # Optional attribute, also validated by the model if present.
    # The model validation checks if the principal that's assigned
    # to the Category is actually in the project of the Category.
    # This also checks if the principal actually exists.
    attribute :assigned_to

    def self.model
      Category
    end

    # Extend the validate method of the ModelContract with extra validations
    # Note that the ModelContract runs validations like attribute validations or
    # model validations and adds the errors together with the contract errors.
    def validate
      user_allowed_to_manage
      validate_project_is_set
      validate_name_is_set
      super
    end

    private

    # Check if the user who called the service has the :manage_categories permission on the project
    def user_allowed_to_manage
      if model.project && !user.allowed_to?(:manage_categories, model.project)
        errors.add :base, :error_unauthorized
      end
    end

    # Check if a project is set (this would also give an error
    # if only a project_id was passed and a project with the id doesn't exist)
    def validate_project_is_set
      errors.add :project, :blank if model.project.nil?
    end

    # Check if a name is set (this would also give an error
    # if only a project_id was passed and a project with the id doesn't exist)
    # In most other models this is checked in the model itself, but for some
    # reason, some models seem to miss validations
    def validate_name_is_set
      errors.add :name, :blank if model.name.nil?
    end
  end
end
