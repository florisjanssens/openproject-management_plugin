#-- copyright
# OpenProject user and project management plugin.
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

#!/bin/bash
test=$(curl -s -H "Authorization: token $GITHUB_TOKEN" 'https://api.github.com/repos/opf/openproject/commits?sha=dev&per_page=200'| jq '.[] | {sha: .sha}')

for row in $(echo "${test}" | jq -r '.[]'); do
    match=$(curl -s -H "Accept: application/vnd.github.antiope-preview+json" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/opf/openproject/commits/${row}/check-runs | jq -r '.check_runs[] | select(.app.slug|test("travis-ci")) | select(.conclusion|test("success"))')
    
    if [ ! -z "$match" ]; then echo "${row}" && break ; fi
done
