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

class BulkCopyProjectSettingsJob < ApplicationJob
  queue_with_priority :low

  attr_reader :user_id,
              :project_id,
              :project_settings

  def perform(user_id:,
              project_id:,
              project_settings:)

    @recipient_id = user_id
    @project_id = project_id
    @project_settings = project_settings

    # It's impossible to send the mail if the recipient wasn't found
    # In this case, this job is just stopped without doing anything
    # This would only happen if the user who queued the job was deleted before
    # the job was started
    return unless recipient

    # Start the copy if the parent_project was found
    # Otherwise, send a mail to the user indicating the copy has failed
    if parent_project.present?
      # Copy the selected project settings
      errors = copy_project_settings
      # Send a mail to the user to indicate the copy is complete
      # The mail also shows any errors encountered
      BulkProjectSetterMailer.copy_settings_completed(recipient, parent_project, errors).deliver_now
    else
      BulkProjectSetterMailer.copy_settings_invalid_project(recipient).deliver_now
    end
  end

  private

  # Copy the selected project settings to its children projects
  def copy_project_settings
    # To hold the error messages
    errors = []

    # Find the active children projects first
    children = find_active_children(parent_project)

    # Copy the selected settings to each active child
    children.each do |child|
      # Note that concat is used many times throughout the code
      # concat is used to append one array to the other
      # Just using << would add arrays to the array while it just
      # needs to contain the error messages. += would return a new array
      # which is expensive. Concat is the best option to achieve what we want
      # and saves a lot of conditionals later. << however, is also useful
      # in this code as it's a good way to add an element to an array (like a
      # specific error message that isn't in an array)
      errors.concat(copy_settings_to_child(child))
    end

    errors
  end

  def copy_settings_to_child(to_project)
    errors = []

    # Copy selected settings to the child
    project_settings.each_key do |setting|
      next if setting.blank?

      creation_errors = nil

      case setting
      when "attributes"
        # Copy the selected project attributes first (description, status,
        # public state, modules, work package types, custom fields)
        creation_errors = copy_project_attributes(to_project)
      when "versions"
        # Copy the selected version settings
        creation_errors = copy_project_versions(to_project)
      when "categories"
        # Copy the selected work package category settings
        creation_errors = copy_project_categories(to_project)
      else
        next
      end

      errors.concat(convert_errors_to_action(creation_errors, "copying #{setting} to #{to_project.name}"))
    end

    errors
  end

  # Copy the selected project attributes (description, status, public state, modules, work package types, custom fields)
  # This works by constructing a hash of parameters based on the given settings
  # and then calling the UpdateService with these parameters
  def copy_project_attributes(to_project)
    errors = []

    # Check if the user has the right permissions to edit the project attributes
    unless recipient.allowed_to?(:edit_project, to_project)
      errors << "You don't have permission to edit the attributes of this project."
      return errors
    end

    update_parameters, construction_errors = construct_child_attribute_parameters(to_project)
    errors.concat(construction_errors)

    unless update_parameters.empty?
      service_result = Projects::UpdateService
                       .new(user: recipient,
                            model: to_project)
                       .call(update_parameters)

      errors.concat(service_result.errors.full_messages)
    end

    errors
  end

  # Copy the selected version settings
  # Supports copying of version dates, descriptions, statuses and also
  # adding non-closed, non-shared versions of the parent_project to the to_project
  # if they don't exist in the to_project yet
  def copy_project_versions(to_project)
    errors = []

    # Check if the user has the right permissions to manage the versions of this project
    unless recipient.allowed_to?(:manage_versions, to_project)
      errors << "You don't have permission to manage versions of this project."
      return errors
    end

    # First, handle existing versions (copies dates, descriptions and statuses based on the selected settings)
    errors.concat(copy_existing_project_versions(to_project))

    # Then handle new versions (if the user chose to copy new versions)
    errors.concat(copy_new_project_versions(to_project))

    errors
  end

  # Copy the selected work package category settings to another project
  def copy_project_categories(to_project)
    errors = []

    # Check if the user has the right permissions to manage the categories of this project
    unless recipient.allowed_to?(:manage_categories, to_project)
      errors << "You don't have permission to manage categories of this project."
      return errors
    end

    # Create categories in the to_project from the parent_project which don't exist yet for the to_project
    if project_settings["categories"].include?("new_categories")
      to_copy = find_parent_categories_not_in_project(to_project)
      to_copy.each do |category|
        errors.concat(copy_new_category(category, to_project))
      end
    end

    errors
  end

  def construct_child_attribute_parameters(to_project)
    to_copy = ["description", "public", "status", "enabled_module_names",
               "type_ids", "work_package_custom_field_ids"]
    to_copy = find_whitelisted_settings(to_copy, project_settings["attributes"])

    to_copy, errors = filter_attribute_settings_by_permission(to_project, to_copy)

    update_params = parent_project.slice(*to_copy)

    if to_copy.include?("status")
      update_params[:status] = if update_params[:status].present?
                                 update_params[:status].slice("code", "explanation")
                               else
                                 update_params[:status] = { code: nil,
                                                            explanation: nil }
                               end
    end

    [update_params, errors]
  end

  def filter_attribute_settings_by_permission(to_project, chosen_settings)
    new_settings = []
    errors = []

    chosen_settings.each do |setting|
      case setting
      when "enabled_module_names"
        if recipient.allowed_to?(:select_project_modules, to_project)
          new_settings << setting
        else
          errors << "You don't have permission to edit the modules of this project."
        end
      when "type_ids"
        if recipient.allowed_to?(:manage_types, to_project)
          new_settings << setting
        else
          errors << "You don't have permission to edit the work package types of this project."
        end
      else
        new_settings << setting
      end
    end

    [new_settings, errors]
  end

  def copy_existing_project_versions(to_project)
    errors = []

    # For each version with a same name found in the to_project, a hash of parameters with the updated attributs
    # is constructed based on the selected settings after which the UpdateService of Versions is called to update the version
    to_project.versions.each do |version|
      # If a version with the same name was found in the to_project, the copying can start for this version
      from_version = find_matching_parent_version_by_name(version)
      next unless from_version.present?

      errors.concat(copy_existing_version(from_version, version))
    end

    errors
  end

  def copy_new_project_versions(to_project)
    errors = []

    # If selected, add non-closed, non-shared versions of the parent_project to the to_project if they don't exist yet
    # First it finds the versions which need to be added after which they are copied by creating them with the same
    # parameters for the to_project using the CreateService of Versions
    if project_settings["versions"].include?("new_versions")
      to_copy = find_parent_versions_not_in_project(to_project)
      # Copy each found version
      to_copy.each do |version|
        errors.concat(copy_new_version(version, to_project))
      end
    end

    errors
  end

  def find_matching_parent_version_by_name(version)
    parent_project.versions.find { |p_version| p_version.name == version.name }
  end

  def copy_existing_version(from_version, to_version)
    errors = []

    to_copy = ["effective_date", "start_date", "description", "status"]
    to_copy = find_whitelisted_settings(to_copy, project_settings["versions"])
    update_params = from_version.slice(*to_copy)

    service_result = Versions::UpdateService
                       .new(user: recipient,
                            model: to_version)
                       .call(update_params)

    errors.concat(service_result.errors.full_messages)

    errors
  end

  def find_whitelisted_settings(whitelisted, settings)
    settings.select { |setting| whitelisted.include? setting }
  end

  def find_parent_versions_not_in_project(project)
    # Finds all the non-closed, non-shared versions of the parent_project which don't exist yet in the to_project (by name)
    parent_project.versions.find_all do |v|
      v.status != "closed" &&
        v.sharing == "none" &&
        project.versions.map(&:name).exclude?(v.name)
    end
  end

  def copy_new_version(version, to_project)
    errors = []

    parameters = version.slice("name", "description", "effective_date", "start_date")
    parameters["project_id"] = to_project.id
    service_result = Versions::CreateService
                       .new(user: recipient)
                       .call(parameters)

    errors.concat(service_result.errors.full_messages)

    errors
  end

  def find_parent_categories_not_in_project(project)
    parent_project.categories.find_all { |v| project.categories.map(&:name).exclude?(v.name) }
  end

  def copy_new_category(category, to_project)
    errors = []

    service_result = Categories::CreateService
                       .new(user: recipient)
                       .call({ project_id: to_project.id,
                               name: category.name })

    errors.concat(service_result.errors.full_messages)

    errors
  end

  # Used to add an action to all errors in the error array
  def convert_errors_to_action(errors, action_string)
    errors.map { |error_msg| "While #{action_string}: #{error_msg}" }
  end

  def recipient
    @recipient ||= User.find_by(id: @recipient_id)
  end

  # Finds the parent project and puts it in @parent_project
  # Note that the database operation is only done if @parent_project
  # is nil, undefined, etc. So it's possible to keep calling this method
  # without doing unnecessary operations.
  def parent_project
    @parent_project ||= Project.find_by(id: @project_id)
  end

  # Returns projects which are children of the given project and are still active (and not archived)
  def find_active_children(parent_project)
    parent_project.children.where("active")
  end
end
