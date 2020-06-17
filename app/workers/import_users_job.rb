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

class ImportUsersJob < ApplicationJob
  queue_with_priority :low

  attr_reader :user_id,
              :authentication_method,
              :identity_url_prefix,
              :create_non_existing,
              :csv_file_path

  # Name of the default role given to users/groups when added to a project
  # when a role wasn't defined
  DEFAULT_ROLE_NAME = "Member".freeze

  def perform(user_id:,
              authentication_method:,
              identity_url_prefix:,
              create_non_existing:,
              csv_file_path:)

    @recipient_id = user_id
    @authentication_method = authentication_method
    @identity_url_prefix = identity_url_prefix
    @create_non_existing = create_non_existing

    # The CSV is passed to this job by using the OpenProject attachment system
    # as passing path to a tempfile would be a bad idea. The tempfile could
    # dissapear before this job starts as there is only a reference to the path
    # of the file which doesn't prevent it from being removed.
    # However, the attachment system starts a job that will remove the attachment
    # if it isn't linked to something (like a wiki). The attachment will be removed
    # if it's over 3 hours old by default.
    # This will probably not be necessary but we copy the file to a new tempfile
    # before importing to make sure it doesn't dissapear while importing.
    @csv_file = Tempfile.new

    begin
      return unless recipient

      copy_file(csv_file_path.local_path, @csv_file)

      errors = import_users
      UserImportMailer.import_users_completed(recipient, errors, created).deliver_now
    ensure
      # Delete the files at the end (or if something went wrong)
      csv_file_path.destroy
      @csv_file.close
      @csv_file.unlink
    end
  end

  private

  # Process the complete CSV and import users, global roles, project roles
  # and projects based on the combination of values for each row
  def import_users
    # To hold the error messages
    errors = []

    # Using foreach prevents using large amounts of memory (read line by line)
    CSV.foreach(@csv_file, headers: true).with_index(2) do |row, line|
      errors.concat(import_csv_row(row, line))
    end

    errors
  end

  # Process the current row of the CSV and import users, global roles, project roles
  # and projects based on the combination of filled in columns
  def import_csv_row(row, line)
    user, user_errors = import_user_from_row(row, line)
    return user_errors unless user_errors.empty?

    group, group_errors = import_group_from_row(row, line, user)
    return group_errors unless group_errors.empty?

    role, role_errors = import_role_from_row(row, line, user)
    return role_errors unless role_errors.empty?

    import_projects_from_row(row, line, user, group, role)
  end

  # Import the user specified in the current row
  # Creates the user if it doesn't exist
  # Also checks if the right fields are filled in beforehand
  def import_user_from_row(row, line)
    errors = []
    user = nil

    username = row["username"]

    if username.present?
      user = find_user_by_username(username)
      unless user
        field_errors = check_user_fields(row)
        return user, convert_errors_to_line_action(field_errors, line, "checking user fields") unless field_errors.empty?

        user, errors = create_new_user(row)
      end
    end

    [user, convert_errors_to_line_action(errors, line, "creating user")]
  end

  # Import a group if the group column was filled in
  # Creates the group if it doesn't exist and adds the user to the group
  # if the user isn't a member yet
  def import_group_from_row(row, line, user)
    errors = []
    group = nil

    group_name = row["group"]

    if group_name.present?
      group = find_group_by_groupname(group_name)

      unless group
        if create_non_existing
          group, errors = create_new_group(group_name)
        else
          errors << "You chose to not create non-existing objects, the specified group should exist beforehand."
        end

        errors = convert_errors_to_line_action(errors, line, "creating group")
      end

      if group
        errors.concat(convert_errors_to_line_action(check_add_user_to_group(user, group), line, "adding user to group"))
      end
    end

    [group, errors]
  end

  # Import a role if a project column or the role column was filled in for the row
  # The role is a project role if a project column was filled in
  # The project role will be the given role in the role column or the default role
  # The role is a global role if no project column was filled in and only the role
  # column was filled in
  def import_role_from_row(row, line, user)
    errors = []
    role = nil

    if row["parent_project"].present? || row["sub_project"].present?
      role, errors = import_project_role_from_row(row, line)
    elsif row["role"].present?
      role, errors = import_global_role_from_row(row, line, user)
    end

    [role, errors]
  end

  # Import a project role
  # The role will be the role in the role column if filled in
  # or the default role
  # The role is only created here if it doesn't exist
  # and will be used later
  def import_project_role_from_row(row, line)
    errors = []

    role_name = row["role"].present? ? row["role"] : DEFAULT_ROLE_NAME

    role = find_role_by_name(role_name)

    unless role
      if create_non_existing
        role, errors = create_project_role(role_name)
      else
        errors << "You chose to not create non-existing objects, the specified role should exist beforehand."
      end
    end

    [role, convert_errors_to_line_action(errors, line, "creating role")]
  end

  # Import a global role
  # Creates the role if it doesn't exist and give the user
  # the role if the user doesn't have the role yet
  def import_global_role_from_row(row, line, user)
    errors = []

    role_name = row["role"]
    role = find_role_by_name(role_name)

    unless role
      create_errors = []

      if create_non_existing
        role, create_errors = create_global_role(role_name)
      else
        create_errors << "You chose to not create non-existing objects, the specified role should exist beforehand."
      end

      errors.concat(convert_errors_to_line_action(create_errors, line, "creating role"))
    end

    if role
      add_errors = check_add_user_to_global_role(user, role)

      errors.concat(convert_errors_to_line_action(add_errors, line, "adding user to role"))
    end

    [role, errors]
  end

  # Import the parent project or sub project (if filled in for the current row)
  # and add the member of the current row (user or group) to the
  # bottom project (the parent if only one of the project columns was filled in
  # or the sub project if both project columns are filled in)
  def import_projects_from_row(row, line, user, group, role)
    # Import the parent project if filled in for the current row
    # Note that the parent will become the project in the parent column of the row
    # if the parent column was filled in OR the project in the sub project column
    # if only the sub project column was filled in (the sub will become the parent
    # in this case)
    parent_project, parent_errors = import_parent_project_from_row(row, line)
    return parent_errors unless parent_errors.empty?

    # Import the sub project if the sub project column was filled in and parent_project
    # is not nil
    sub_project, sub_errors = import_sub_project_from_row(row, line, parent_project)
    return sub_project unless sub_errors.empty?

    # Add the member of the current column to the bottom project with a given role
    # (if any project was given and the member isn't in the project yet)
    # The member is the group if a group was filled in or the given user otherwise
    # The bottom project is the parent if only a parent was imported or the
    # sub project otherwise
    import_bottom_project_membership(line, user, group, role, parent_project, sub_project)
  end

  # Import the parent project if the parent project column was filled in for the row
  # or if only the sub project column was filled (then the sub is the parent)
  def import_parent_project_from_row(row, line)
    errors = []
    parent_project = nil

    parent_identifier = row["parent_project"].present? ? row["parent_project"] : row["sub_project"]

    # If the parent_identifier is present, then at least one project column was filled in and a project
    # should be created
    if parent_identifier.present?
      # Search if the project already exists
      parent_project = find_project_by_identifier(parent_identifier)

      # Create the project if it wasn't found
      unless parent_project
        if create_non_existing
          parent_project, errors = create_new_project(parent_identifier)
        else
          errors << "You chose to not create non-existing objects, the specified parent project should exist beforehand."
        end
      end
    end

    [parent_project, convert_errors_to_line_action(errors, line, "creating project")]
  end

  # Import a sub project of a given parent project if the parent
  # exists and the sub project column of the current row was filled in
  def import_sub_project_from_row(row, line, parent_project)
    errors = []
    sub_project = nil

    sub_identifier = row["sub_project"]

    return sub_project, errors unless parent_project && sub_identifier.present?

    sub_project = find_project_by_identifier(sub_identifier)

    unless sub_project
      if create_non_existing
        # Create subproject (copy of parent in this case)
        ProjectMailer.with_deliveries(false) do
          sub_project, errors = full_copy_project_to_sub(parent_project, sub_identifier)
        end
      else
        errors << "You chose to not create non-existing objects, the specified sub-project should exist beforehand."
      end
    end

    [sub_project, convert_errors_to_line_action(errors, line, "creating sub-project")]
  end

  # Add the member of the current row to the bottom project of the current row with a given role (or default role)
  # The member is the group if given or the user otherwise
  # The bottom project is the sub project if both a parent and a sub project are given
  # and the parent project otherwise
  def import_bottom_project_membership(line, user, group, role, parent_project, sub_project)
    errors = []

    return errors unless [parent_project, sub_project].any?

    # The user could have specified the name of a global role in the role column
    # while using the combination to create projects and add members with a project role
    # In this case, show an error as a global role can't be given as a role in a project
    # Else, add the member to the bottom project with the given role (or default)
    if global_role?(role)
      errors << "The specified role is an existing global role. If a parent or sub-project was filled in," \
                "the role should be a new role or an existing project role."
    else
      # Find the bottom project first
      bottom_project = find_bottom_project(parent_project, sub_project)

      # Find the member to add (remember that both group and user are Principals in the DB structure)
      member = group || user

      # Check if the member is already in the project
      membership = find_membership_by_project(member, bottom_project)

      if membership
        # Member is already in the project
        # If the member doesn't have the defined role in the project
        # Give the member the role in the project
        check_add_role_to_membership(membership, role)
      else # Member isn't in the project yet, add it to the project
        errors = add_member_to_project(member, bottom_project, role)
      end
    end

    convert_errors_to_line_action(errors, line, "adding user to project")
  end

  # Creates a new user with the given attributes
  # If the identity URL isn't nil, the user will become an active user
  # with the given identity URL. Otherwise, the user will become an
  # invited user which will receive a token to activate its account
  def create_new_user(row)
    user = User.new(extract_new_user_params(row))

    service_result = ::Users::CreateUserService
                        .new(current_user: recipient)
                        .call(user)

    if service_result.success?
      created["users"] += 1
    end

    [user, service_result.errors.full_messages]
  end

  def extract_new_user_params(row)
    # If the authentication method is by identity_url_provider,
    # the full identity_url is constructed. Otherwise the
    # identity_url will become nil.
    identity_url = "#{identity_url_prefix}:#{row['identity_url']}" if
                     authentication_method == "identity_url_provider"

    params = { login: row["username"],
               firstname: row["first_name"].capitalize,
               lastname: row["last_name"].capitalize,
               mail: row["email"],
               admin: row["administrator"],
               identity_url: identity_url,
               status: status }

    params
  end

  # Create a new group with the given name
  def create_new_group(groupname)
    service_result = ::Groups::CreateService
                        .new(user: recipient)
                        .call({ groupname: groupname.capitalize })

    if service_result.success?
      created["groups"] += 1
    end

    [service_result.result, service_result.errors.full_messages]
  end

  # Adds a user to a group if the user isn't in the group yet
  def check_add_user_to_group(user, group)
    return [] if user_in_group?(user, group)

    service_result = ::Groups::AddUsersService
                     .new(group, current_user: recipient)
                     .call([user.id])

    service_result.errors.full_messages
  end

  # Create a global role
  def create_global_role(name)
    type = "GlobalRole"
    assignable = false

    role, errors = create_new_role(name, assignable, type)

    [role, errors]
  end

  # Create a project role
  def create_project_role(name)
    type = "Role"
    assignable = true

    role, errors = create_new_role(name, assignable, type)

    [role, errors]
  end

  # Create a new role with the given attributes
  # The role will become a global role if type is "GlobalRole"
  # or a project role if type is "Role".
  # The role should only be assignable (to a project) if it's a project role
  def create_new_role(name,
                      assignable,
                      type)

    service_result = ::Roles::CreateService
                        .new(user: recipient)
                        .call({ name: name.capitalize,
                                assignable: assignable,
                                type: type })

    if service_result.success?
      created["roles"] += 1
    end

    [service_result.result, service_result.errors.full_messages]
  end

  # Return true if the user has the given global role
  # Otherwise, false
  def user_has_global_role?(user, role)
    user.principal_roles.find_by(role_id: role.id).present?
  end

  # Adds a user to a global role
  def check_add_user_to_global_role(user, global_role)
    errors = []

    # If the importer filled in the fields with the combination to create
    # a global role but put in the name of a project role that already exists,
    # then show an error.
    # If the role is indeed global and the user doesn't have the role yet,
    # add the user to the role
    if global_role.type == "GlobalRole"
      unless user_has_global_role?(user, global_role)
        service_result = ::PrincipalRoles::CreateService
                .new(user: recipient)
                .call({ role_id: global_role.id, principal_id: user.id })

        errors = service_result.errors.full_messages
      end
    else
      errors << "The specified role is not a global role. If no parent or sub-project was" \
                "filled in, the role should be a new role or an existing global role."
    end

    errors
  end

  # Create a new project
  def create_new_project(identifier)
    # The identifier is parameterized because the import would
    # still work in case the user didn't feel like reading the tutorial and entered
    # a project name instead of an identifier. Basically converts most things that can
    # be intered into a valid identifier
    service_result = ::Projects::CreateService
                       .new(user: recipient)
                       .call({ name: identifier.titleize,
                               identifier: identifier.parameterize })
    if service_result.success?
      created["projects"] += 1
    end

    [service_result.result, service_result.errors.full_messages]
  end

  # Copy a project and its attributes/associations to a sub-project
  def full_copy_project_to_sub(parent_project, identifier)
    sub_project, errors = copy_project_attributes_to_sub(parent_project, identifier)

    if errors.empty? && sub_project.save
      created["projects"] += 1
      errors = copy_project_associations_to_sub(parent_project, sub_project)
    else
      errors << service_result.errors.merge(sub_project.errors).full_messages
    end

    [sub_project, errors]
  end

  # Copy project attributes to a sub_project and return the result
  # The attributes of a project are: description, status, public state,
  # custom fields, work package types, enabled modules
  def copy_project_attributes_to_sub(parent_project, identifier)
    sub_project = Project.new

    update_params = extract_project_attribute_params(parent_project, identifier)

    service_result = ::Projects::SetAttributesService
                          .new(user: recipient,
                               model: sub_project,
                               contract_class: ::Projects::CopyContract,
                               contract_options: { copied_from: parent_project })
                          .call(update_params)

    [sub_project, service_result.errors.full_messages]
  end

  # Copy project associations to a sub_project and return the result
  # The associations are the work packages, work package attachments,
  # the versions, the queries, the categories, the forums, wiki pages
  # and wiki attachments
  # Members aren't copied to give more control to the importer
  def copy_project_associations_to_sub(parent_project, sub_project)
    errors = []

    to_copy = %i[work_packages work_package_attachments versions
                 queries categories forums wiki wiki_page_attachments]
    # Copy associations from the parent to the sub-project. Basically copies
    # whatever is in the parent project to the sub (except members)
    sub_project.copy_associations(parent_project, only: to_copy)
    # After copying associations, some objects may have not been copied successfully in some cases
    # This adds possible validation errors to the errors returned by the method
    error_objects = project_errors(sub_project)
    error_objects.each do |error_object|
      error_prefix = error_prefix_for(error_object)
      error_object.full_messages.flatten.each do |error|
        errors << error_prefix + error
      end
    end

    errors
  end

  # Extract the project attribute parameters from a parent_project
  def extract_project_attribute_params(parent_project, identifier)
    update_params = parent_project.slice("description", "status", "public", "work_package_custom_field_ids",
                                         "type_ids", "enabled_module_names")

    # The status of the parent could be nil, in this case the status fields of
    # the sub project are set to nil to achieve the same effect. Otherwise the
    # status fields of the parent are chosen.
    update_params[:status] = if update_params[:status].present?
                               update_params[:status].slice("code", "explanation")
                             else
                               update_params[:status] = { code: nil,
                                                          explanation: nil }
                             end

    update_params[:name] = identifier.titleize
    # The identifier is parameterized because the import would
    # still work in case the user didn't feel like reading the tutorial and entered
    # a project name instead of an identifier. Basically converts most things that can
    # be intered into a valid identifier
    update_params[:identifier] = identifier.parameterize
    update_params[:parent_id] = parent_project.id

    update_params
  end

  def project_errors(project)
    (project.compiled_errors.flatten + [project.errors]).flatten
  end

  def error_prefix_for(error_object)
    base = error_object.instance_variable_get(:@base)
    base.is_a?(Project) ? '' : "#{base.class.model_name.human} '#{base}': "
  end

  # Adds a member to a project with a specific project role
  def add_member_to_project(member, project, role)
    service_result = ::Members::CreateService
                          .new(user: recipient)
                          .call({ principal: member,
                                  project: project,
                                  roles: [role] })

    service_result.errors.full_messages
  end

  # Adds another role to an existing membership (if the membership doesn't have the role yet)
  # This means the user (by its membership) already has a role in a project but gets another one
  def check_add_role_to_membership(membership, role)
    errors = []

    unless role_in_membership?(membership, role)
      role_ids = membership.roles.map(&:id) << role.id

      service_result = ::Members::UpdateService
                            .new(user: recipient,
                                 model: membership)
                            .call({ role_ids: role_ids })

      errors = service_result.errors.full_messages
    end

    errors
  end

  # Check if a value was entered for a given set of attributes for the given row
  def check_user_fields(row)
    errors = []

    # Check if the user info is filled in for the current row at minimum
    minimal_header_attributes.each do |attr|
      unless row[attr].present?
        errors << "The '#{attr}' column can't be blank."
      end
    end

    # Check if the administrator column has a valid value (either true or false)
    unless row["administrator"] == "true" || row["administrator"] == "false"
      errors << "The value entered in the 'administrator' column should be 'true' or 'false'."
    end

    errors
  end

  # Find a user by its username
  # Returns the user if found (or nil)
  def find_user_by_username(username)
    User.find_by(login: username)
  end

  # Find a group by its groupname
  # returns the group if found (or nil)
  def find_group_by_groupname(groupname)
    Group.includes(:users).find_by(groupname: groupname.capitalize)
  end

  def user_in_group?(user, group)
    group.users.find_by(id: user.id).present?
  end

  # Find a role by its name
  # returns the role if found (or nil)
  def find_role_by_name(name)
    Role.find_by(name: name.capitalize)
  end

  # Find a project by its identifier
  # returns the project if found (or nil)
  def find_project_by_identifier(identifier)
    Project.find_by(identifier: identifier.parameterize)
  end

  # Find if the user is a member of a project
  # returns the membership if found (or nil)
  def find_membership_by_project(member, project)
    member.memberships.find_by(project_id: project.id)
  end

  # Find if a certain membership has a certain role
  # returns the role if found (or nil)
  # Basically looks if the user (by its membership) has a certain role in a project
  def role_in_membership?(membership, role)
    membership.roles.find_by(name: role.name).present?
  end

  # Find the bottom project (project with lowest hierarchy)
  # This will be the sub project if both the sub and parent are filled in
  # Or the parent project otherwise
  def find_bottom_project(parent_project, sub_project)
    parent_project && sub_project ? sub_project : parent_project
  end

  def global_role?(role)
    role.type == "GlobalRole"
  end

  # Used to add a line number and action to all errors in the error array
  def convert_errors_to_line_action(errors, line_num, action_string)
    errors.map { |error_msg| "At line #{line_num} (while #{action_string}): #{error_msg}" }
  end

  # Copy a file to another file
  def copy_file(input, output)
    # IO.copy_stream uses a 16 kb buffer internally
    # so a large file doesn't use up all of the available memory
    File.open(input, "rb") do |input_stream|
      File.open(output, "wb") do |output_stream|
        IO.copy_stream(input_stream, output_stream)
      end
    end
  end

  # To hold the statistics
  # ||= means that @created is set to a hash with empty statistic counters
  # if @created is nil, false or undefined.
  # Otherwise, @created is returned.
  # This sets the statistic counters to zero the first time created is called.
  # For subsequent calls, @created is returned (so it returns the statistics
  # in the state they were left by the previous use as long as they weren't left
  # nil, false or undefined)
  def created
    @created ||= {
      "users" => 0,
      "groups" => 0,
      "roles" => 0,
      "projects" => 0
    }
  end

  # Return the minimal header attributes that should be filled in when creating
  # a new user (depending on the authentication method).
  # Note that the attributes are only determined once here thanks to the use
  # of ||=. This makes sure to not repeat the conditional for every user created
  # as the authentication method will stay the same anyway
  def minimal_header_attributes
    @minimal_header_attributes ||= []

    if @minimal_header_attributes.blank?
      @minimal_header_attributes = ["username", "email", "first_name", "last_name", "administrator"]
      @minimal_header_attributes << "identity_url" if authentication_method == "identity_url_provider"
    end

    @minimal_header_attributes
  end

  # Status given to new users is active when using an identity URL provider
  # as the authentication method, otherwise, the status is invited
  def status
    @status ||= if authentication_method == "identity_url_provider"
                  Principal::STATUSES[:active]
                else
                  Principal::STATUSES[:invited]
                end
  end

  def recipient
    @recipient ||= User.find_by(id: @recipient_id)
  end
end
