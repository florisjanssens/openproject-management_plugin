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

module OpenProject::ManagementPlugin::Patches::UsersControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      require 'csv'

      verify method: :post, only: :csv_import_submit, render: { nothing: true, status: :method_not_allowed }
      before_action :check_csv_file_param, only: %i[csv_import_submit]
      before_action :check_authentication_method_param, only: %i[csv_import_submit]
      before_action :check_identity_url_prefix_param,
                    only: %i[csv_import_submit],
                    if: -> { params[:authentication_method_select] == "identity_url_provider" }
      before_action :validate_csv_file_headers, only: %i[csv_import_submit]
      before_action :persist_csv_file, only: %i[csv_import_submit]

      def show_local_breadcrumb
        true
      end
    end
  end

  module InstanceMethods
    def csv_import; end

    def csv_import_tutorial; end

    def csv_import_submit
      authentication_method = params[:authentication_method_select]
      identity_url_prefix = params[:identity_url_prefix_textfield]
      create_non_existing = params[:create_non_existing_checkbox]

      enqueue_import_users_job(authentication_method, identity_url_prefix, create_non_existing, @csv_attachment)

      respond_to do |format|
        format.html do
          import_started_notice
          redirect_to users_path
        end
      end
    end

    private

    def check_csv_file_param
      path = params[:csv_file_input]&.path

      # Show an error if no file was selected, the file is not readable or if the file isn't a .csv
      # Notice that the file not being selected should never happen as the Angular frontend
      # of the corresponding plugin view has been configured to detect this at client-side.
      unless path && File.readable?(path) && path.split('.').last.to_s.downcase == "csv"
        flash[:error] = "No file was selected or the selected file is not a readable .csv file."
        redirect_to action: :csv_import
      end
    end

    def check_identity_url_prefix_param
      identity_url_prefix = params[:identity_url_prefix_textfield]

      unless identity_url_prefix &&
             identity_url_prefix.length <= 40 &&
             identity_url_prefix.match?(/\A[a-zA-Z0-9]([a-zA-Z0-9_-]?[a-zA-Z0-9])*\Z/i)
        flash[:error] = "Please select a valid identity URL prefix."
        redirect_to action: :csv_import
      end
    end

    # Validate the authentication method
    # Normally, this is already done client-side
    # Even though OpenProject doesn't function without javascript enabled
    # validation should still be done client-side
    def check_authentication_method_param
      authentication_method = params[:authentication_method_select]

      unless authentication_method &&
             ["identity_url_provider", "email_invite"].include?(authentication_method)
        flash[:error] = "Please select a valid authentication method."
        redirect_to action: :csv_import
      end
    end

    def get_allowed_csv_headers(authentication_method)
      allowed_header_attr = ["username", "email", "first_name", "last_name", "administrator",
                             "group", "role", "parent_project", "sub_project"]
      allowed_header_attr << "identity_url" if authentication_method == "identity_url_provider"

      allowed_header_attr
    end

    def validate_csv_file_headers
      errors = []

      csv_file = params[:csv_file_input]

      allowed_header_attr = get_allowed_csv_headers(params[:authentication_method_select])

      headers = CSV.foreach(csv_file.path).first
      allowed_header_attr.each do |attr|
        unless headers.include? attr
          errors << "The chosen CSV doesn't contain the '#{attr}' column in the header."
        end
      end

      unless errors.empty?
        flash[:error] = errors
        redirect_to action: :csv_import
      end
    end

    # To pass the CSV path to the job, it has to be saved first.
    # The (bad) alternative is to pass a path to a temp file, which
    # is a bad idea considering the file could get cleaned up
    # before or while executing the job.
    # This stores the file as an OpenProject attachment and deletes
    # it later at the end of the job.
    # In the rare case the job gets interrupted before deleting the file,
    # or the job doesn't even start because of a system reset for example,
    # the file would get deleted automatically by an OpenProject system job.
    def persist_csv_file
      csv_file = params[:csv_file_input]

      @csv_attachment = Attachment.create!(file: csv_file,
                                           description: csv_file.original_filename,
                                           author: current_user)
    rescue StandardError => e
      flash[:error] = "Failed to save the CSV file to the system: #{e.message}"
      redirect_to action: :csv_import
    end

    def import_started_notice
      flash[:notice] = "The import has been started, you will receive an email once the import is done."
    end

    def enqueue_import_users_job(authentication_method,
                                 identity_url_prefix,
                                 create_non_existing,
                                 attachment)
      ImportUsersJob.perform_later(user_id: User.current.id,
                                   authentication_method: authentication_method,
                                   identity_url_prefix: identity_url_prefix,
                                   create_non_existing: create_non_existing,
                                   csv_file_path: attachment)
    end
  end
end
