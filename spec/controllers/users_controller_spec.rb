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

describe UsersController, type: :controller do
  let(:current_user) { FactoryBot.create(:admin) }

  let(:header) { "username,email,first_name,last_name,identity_url,administrator,group,role,parent_project,sub_project" }
  let(:rows) { [header] }

  let(:file_path) { "tmp/test.csv" }
  let!(:csv) do
    CSV.open(file_path, "w") do |csv|
      rows.each do |row|
        csv << row.split(",")
      end
    end
  end

  let(:authentication_method) { "email_invite" }
  let(:identity_url_prefix) { nil }
  let(:create_non_existing) { true }

  let(:submit_parameters) do
    {
      authentication_method_select: authentication_method,
      identity_url_prefix_textfield: identity_url_prefix,
      create_non_existing_checkbox: create_non_existing,
      csv_file_input: Rack::Test::UploadedFile.new("#{Rails.root}/#{file_path}")
    }
  end

  after(:each) { File.delete(file_path) if csv }

  def import_csv(parameters)
    post :csv_import_submit, params: parameters
  end

  before do
    login_as(current_user)
  end

  describe '#csv_import_submit' do
    shared_examples_for 'valid input' do
      it 'shows a notification indicating that the import has been started' do
        import_csv(submit_parameters)
        expect(flash[:notice]).to eq("The import has been started, you will receive an email once the import is done.")
      end

      it 'redirects to the users#index page' do
        import_csv(submit_parameters)
        expect(response).to redirect_to(controller: 'users', action: 'index')
      end

      it 'uploads an attachment' do
        expect do
          import_csv(submit_parameters)
        end.to change { Attachment.count }.by 1
      end

      it 'schedules a bulk import job' do
        expect(ImportUsersJob).to receive(:perform_later)
        import_csv(submit_parameters)
      end
    end

    shared_examples_for 'invalid input' do
      it 'redirects to the users#csv_import page' do
        import_csv(submit_parameters)
        expect(response).to redirect_to(controller: 'users', action: 'csv_import')
      end

      it 'does not upload an attachment' do
        expect do
          import_csv(submit_parameters)
        end.to change { Attachment.count }.by 0
      end

      it 'does not schedule a bulk import job' do
        expect(ImportUsersJob).not_to receive(:perform_later)
        import_csv(submit_parameters)
      end
    end

    context 'as an admin' do
      context 'with valid parameters' do
        include_examples 'valid input'
      end

      context 'with a file that does not have the .CSV extension' do
        let(:file_path) { "tmp/test.txt" }

        it 'shows an error indicating the file is not a CSV' do
          import_csv(submit_parameters)
          message = "No file was selected or the selected file is not a readable .csv file."
          expect(flash[:error]).to eq(message)
        end

        include_examples 'invalid input'
      end

      context 'without a CSV file' do
        let(:submit_parameters) do
          {
            authentication_method_select: authentication_method,
            identity_url_prefix_textfield: identity_url_prefix,
            create_non_existing_checkbox: create_non_existing
          }
        end

        it 'shows an error indicating no file was chosen' do
          import_csv(submit_parameters)
          message = "No file was selected or the selected file is not a readable .csv file."
          expect(flash[:error]).to eq(message)
        end

        include_examples 'invalid input'
      end

      context 'without an authentication method' do
        let(:submit_parameters) do
          {
            identity_url_prefix_textfield: identity_url_prefix,
            create_non_existing_checkbox: create_non_existing,
            csv_file_input: Rack::Test::UploadedFile.new("#{Rails.root}/#{file_path}")
          }
        end

        it 'shows an error indicating no authentication method was chosen' do
          import_csv(submit_parameters)
          message = "Please select a valid authentication method."
          expect(flash[:error]).to eq(message)
        end

        include_examples 'invalid input'
      end

      context 'with an invalid authentication_method' do
        let(:authentication_method) { "invalid" }

        it 'shows an error indicating the authentication method is invalid' do
          import_csv(submit_parameters)
          message = "Please select a valid authentication method."
          expect(flash[:error]).to eq(message)
        end

        include_examples 'invalid input'
      end

      context 'with identity_url_provider as the authentication method' do
        let(:authentication_method) { "identity_url_provider" }

        context 'with a valid identity URL' do
          let(:identity_url_prefix) { "saml" }
          include_examples 'valid input'
        end

        context 'with an invalid identity URL' do
          let(:identity_url_prefix) { "%invalid" }

          it 'shows an error indicating the identity URL prefix is invalid' do
            import_csv(submit_parameters)
            message = "Please select a valid identity URL prefix."
            expect(flash[:error]).to eq(message)
          end

          include_examples 'invalid input'
        end
      end

      context 'with invalid CSV headers' do
        let(:header) { "first_name,last_name,identity_url,administrator,group,role,parent_project,sub_project" }

        it 'shows an error indicating which header columns are missing' do
          import_csv(submit_parameters)
          expect(flash[:error]).to match_array(["The chosen CSV doesn't contain the 'username' column in the header.",
                                                "The chosen CSV doesn't contain the 'email' column in the header."])
        end

        include_examples 'invalid input'
      end
    end

    context 'as a non-admin' do
      let(:current_user) { FactoryBot.create(:user) }

      before do
        import_csv(submit_parameters)
      end

      it 'is not successful' do
        expect(response).not_to be_successful
      end

      it 'returns 403 Forbidden' do
        expect(response.status).to eq(403)
      end

      it 'renders the error page' do
        expect(response).to render_template('common/error')
      end
    end
  end

  describe '#csv_import' do
    before do
      get :csv_import
    end

    context 'as an admin' do
      it 'is successful' do
        expect(response).to be_successful
      end

      it 'returns 200 OK' do
        expect(response.status).to eq(200)
      end

      it 'renders the CSV import page' do
        expect(response).to render_template('users/csv_import')
      end
    end

    context 'as a non-admin' do
      let(:current_user) { FactoryBot.create(:user) }

      it 'is not successful' do
        expect(response).not_to be_successful
      end

      it 'returns 403 unauthorized' do
        expect(response.status).to eq(403)
      end

      it 'renders the error page' do
        expect(response).to render_template('common/error')
      end
    end
  end

  describe '#csv_import_tutorial' do
    before do
      get :csv_import_tutorial
    end

    context 'as an admin' do
      it 'is successful' do
        expect(response).to be_successful
      end

      it 'returns 200 OK' do
        expect(response.status).to eq(200)
      end

      it 'renders the import tutorial page' do
        expect(response).to render_template('users/csv_import_tutorial')
      end
    end

    context 'as a non-admin' do
      let(:current_user) { FactoryBot.create(:user) }

      it 'is not successful' do
        expect(response).not_to be_successful
      end

      it 'returns 403 unauthorized' do
        expect(response.status).to eq(403)
      end

      it 'renders the error page' do
        expect(response).to render_template('common/error')
      end
    end
  end
end
