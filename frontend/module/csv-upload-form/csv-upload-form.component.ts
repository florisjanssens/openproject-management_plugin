/*-- copyright
 * OpenProject management plugin.
 * Copyright (C) 2020 Floris Janssens (florisjanssens@outlook.com)
 *
 * OpenProject is an open source project management software.
 * Copyright (C) 2012-2020 the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2017 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See doc/COPYRIGHT.md for more details.  ++
 */

import {Component, ElementRef, OnInit, ViewChild} from "@angular/core";

@Component({
  selector: 'csv-upload-form',
  templateUrl: './csv-upload-form.html'
})
export class CsvUploadFormComponent implements OnInit {
  // Form targets
  public form:any;
  public target:string;
  public method:string;

  public identityUrlProvider:boolean;

  // File
  public csvFile:any;
  public fileInvalid:boolean;

  @ViewChild('csvFilePicker', { static: true }) public csvFilePicker:ElementRef;
  @ViewChild('authenticationMethodSelect', { static: true}) public authenticationMethodSelect:ElementRef;
  // Text
  public text = {
    label_choose_csv: 'Select CSV to import',
    upload_instructions: 'Please select a CSV file containing comma-separated values.',
    wrong_file_format: 'The file you selected is not a CSV',
    button_import: 'Import',
    label_identity_url_prefix: 'Identity URL prefix',
    identity_url_prefix_textfield: 'e.g. saml',
    identity_url_prefix_instructions: 'Specify the name of the identity provider used to authenticate imported users. This name will prefix the identity URLs mentioned in the CSV (prefix:csv_identity_url) to form the complete identity URL.',
    identity_url_prefix_format_instructions: 'Only alphanumeric values, underscores and hyphens are allowed.',
    legend_import_settings: 'Import settings',
    label_authentication_method: 'User authentication method',
    authentication_method_instructions: 'Select the way in which imported users authenticate with OpenProject. When identity URL is selected, an OAuth identity URL should be specified in the CSV for all users. When email invitation is selected, an email will be sent to new users containing a token which makes it possible for users to activate their own account and authenticate by password.',
    label_create_non_existing: 'Create non-existing groups, roles and projects',
    create_non_existing_instructions: 'Setting this checkbox creates groups, roles or projects mentioned in the CSV if they do not exist yet. These are added with the most basic settings and can be edited later.'
  };

  public authenticationMethods = [
    {"text":"Identity URL", "value":"identity_url_provider"},
    {"text":"Password (email invitation)", "value":"email_invite"}
  ];

  public constructor(protected elementRef:ElementRef) {
  }

  public ngOnInit() {
    const element = this.elementRef.nativeElement;
    this.target = element.getAttribute('target');
    this.method = element.getAttribute('method');

    this.authenticationMethodSelect.nativeElement.value = this.authenticationMethods[0].value;
    this.identityUrlProvider = true;
  }

  public onFilePickerChanged(_evt:Event) {
    this.fileInvalid = false;
    this.csvFile = undefined;

    const files:File[] = Array.from(this.csvFilePicker.nativeElement.files);
    if (files.length === 0) {
      return;
    }


    const file = files[0];
    if (['text/csv', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel'].indexOf(file.type) === -1) {
      this.fileInvalid = true;
      return;
    }

    this.csvFile = file;
  }

  public onAuthenticationMethodSelectChanged(_evt:Event) {
    if (this.authenticationMethodSelect.nativeElement.value === this.authenticationMethods[0].value) {
        this.identityUrlProvider = true;
    } else {
        this.identityUrlProvider = false;
    }
  }
}
