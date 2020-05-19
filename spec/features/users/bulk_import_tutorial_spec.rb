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

feature 'Bulk CSV import tutorial', type: :feature, js: true do
  let(:current_user) { FactoryBot.create(:admin) }

  before do
    login_as current_user
  end

  context 'as an admin' do
    scenario 'Clicking the link in the notification of the bulk import page opens the tutorial' do
      visit bulk_import_path

      click_on('You can click this link if you need any help, including a template you can adapt.')

      expect_tabs(2)

      switch_to_last_tab

      expect_path(bulk_import_tutorial_path)

      expect(page).not_to have_selector('.notification-box--content', text: '[Error 403]')
    end
  end

  context 'as a non-admin' do
    let(:current_user) { FactoryBot.create(:user) }

    scenario 'navigating to the bulk CSV import tutorial page shows the unauthorized message' do
      visit bulk_import_tutorial_path

      expect(page).to have_selector('.notification-box--content', text: '[Error 403]')
    end
  end

  def expect_path(path)
    expect(current_path).to eq(path)
  end

  def expect_tabs(number)
    window = page.driver.browser.window_handles
    expect(window.size).to eq(number)
  end

  def switch_to_last_tab
    window = page.driver.browser.window_handles
    page.driver.browser.switch_to.window(window.last)
  end
end
