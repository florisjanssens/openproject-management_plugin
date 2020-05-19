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

describe BulkProjectSetterMailer, type: :mailer do
  let(:project) { FactoryBot.create(:project) }
  let(:recipient) { FactoryBot.create(:user) }

  describe '#copy_settings_completed' do
    let(:errors) { ["error1", "error2", "error3"] }
    let!(:mail) { BulkProjectSetterMailer.copy_settings_completed(recipient, project, errors) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Bulk copying settings of #{project.name} finished")
      expect(mail.to).to match_array([recipient.mail])
      expect(mail.from).to eq([Setting.mail_from])
    end

    it 'renders the html body' do
      expect(mail.html_part.body).to include(project.name)
      errors.each do |error|
        expect(mail.html_part.body).to include(error)
      end
    end

    it 'renders the text body' do
      expect(mail.text_part.body).to include(project.name)
      errors.each do |error|
        expect(mail.text_part.body).to include(error)
      end
    end
  end

  describe '#copy_settings_invalid_project' do
    let!(:mail) { BulkProjectSetterMailer.copy_settings_invalid_project(recipient) }

    it 'renders the headers' do
      expect(mail.subject).to eq("Bulk copying settings failed")
      expect(mail.to).to match_array([recipient.mail])
      expect(mail.from).to eq([Setting.mail_from])
    end

    it 'renders the html body' do
      expect(mail.html_part.body).to include("failed")
    end

    it 'renders the text body' do
      expect(mail.text_part.body).to include("failed")
    end
  end
end
