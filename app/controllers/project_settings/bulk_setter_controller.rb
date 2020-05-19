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

class ProjectSettings::BulkSetterController < ProjectSettingsController
  menu_item :settings_bulk_setter

  # The project needs to have children to be able to bulk copy settings
  # If it doesn't have children, render the 403 error page.
  # Technically, the user wouldn't be able to get here if the project doesn't have
  # children, but the URL could still be entered manually without this.
  # Nothing can go wrong even if the user could get here, so this is more
  # for completion sake.
  before_action :verify_children_present
  # Authorization and checking if the project actually exists, is already
  # done in the super class. Again, this is just to determine if the bulk setter
  # view can be rendered or not. Even if authorization, etc. wasn't checked here,
  # there are more checks down the line.

  def show
    render template: 'project_settings/bulk_setter'
  end

  private

  def verify_children_present
    render_403 unless @project.children.present?
  end
end
