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

module OpenProject::ManagementPlugin::Patches::ProjectsControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      before_action :authorize, only: %i[bulk_copy_settings]
      verify method: :post, only: :bulk_copy_settings, render: { nothing: true, status: :method_not_allowed }
    end
  end

  module InstanceMethods
    def bulk_copy_settings
      settings = selected_settings_params

      # If there are no selected settings, show an error and don't start the job
      # Note that the view is configured in a way to only pass settings if one is actually selected.
      # the selected_settings hash doesn't exist if nothing was selected, which saves unnecessary checks later.
      # Also note that this should never be reached as client-side validation already prevents this
      # Blank? works here because settings if of the ActionController::Parameters class and not the hash directly
      if settings.blank?
        respond_to do |format|
          format.html do
            no_settings_error
            redirect_to controller: 'project_settings/bulk_setter', action: 'show', id: @project
          end
        end
      # If there is an element in settings, one or more settings should be
      # copied to the sub-projects. To do this, a background job is queued
      # as there could be many sub-projects. Remember that the background job
      # is executed in parallel by a different process (worker process) so the main (web)
      # process doesn't get blocked (having a negative effect on user experience).
      # With many threads this would matter less but it would be bad practice to
      # not run these longer tasks in a background job. Also think about the fact
      # that a user would see the page loading for a very long time (eventually
      # leading to a timeout) when not using a background job.
      else
        enqueue_copy_settings_job(settings)

        respond_to do |format|
          format.html do
            copy_started_notice
            redirect_to controller: 'project_settings/bulk_setter', action: 'show', id: @project
          end
        end
      end
    end

    private

    def enqueue_copy_settings_job(settings)
      BulkCopyProjectSettingsJob.perform_later(user_id: User.current.id,
                                               project_id: @project.id,
                                               project_settings: settings)
    end

    # If the selected_settings params was there, only permit attributes, versions and categories
    # This is needed as Rails throws an error when passing a hash without explicitly filtering the parameters
    # Just using .permit! would also work but allows any parameter in selected_settings to be passed
    # Also, if selected_settings isn't there, it's replaced by {}. This makes selected_settings optional
    # to account for no settings being given in the case client-side validation was bypassed in some way
    def selected_settings_params
      params.fetch(:selected_settings, {}).permit(attributes: [], versions: [], categories: [])
    end

    def copy_started_notice
      flash[:notice] = "The copy has been started, you will receive an email once this is done."
    end

    def no_settings_error
      flash[:error] = "No settings were chosen to be copied."
    end
  end
end
