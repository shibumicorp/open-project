# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
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
# See COPYRIGHT and LICENSE files for more details.
#++

module ProjectCustomFieldProjectMappings
  class BulkCreateService < ::BaseServices::BaseCallable
    def initialize(user:, project:, project_custom_field:, include_sub_projects: false)
      super()
      @user = user
      @project = project
      @project_custom_field = project_custom_field
      @include_sub_projects = include_sub_projects
    end

    def perform
      service_call = validate_permissions
      service_call = validate_contract(service_call, incoming_mapping_ids) if service_call.success?
      service_call = perform_bulk_create(service_call) if service_call.success?

      service_call
    end

    private

    def validate_permissions
      if @user.allowed_in_project?(:select_project_custom_fields, projects)
        ServiceResult.success
      else
        ServiceResult.failure(errors: { base: :error_unauthorized })
      end
    end

    def validate_contract(service_call, project_ids)
      set_attributes_results = project_ids.map do |id|
        set_attributes(project_id: id, custom_field_id: @project_custom_field.id)
      end

      if (failures = set_attributes_results.select(&:failure?)).any?
        service_call.success = false
        service_call.errors = failures.map(&:errors)
      else
        service_call.result = set_attributes_results.map(&:result)
      end

      service_call
    end

    def perform_bulk_create(service_call)
      ProjectCustomFieldProjectMapping.import(service_call.result, validate: false)

      service_call
    rescue StandardError => e
      service_call.success = false
      service_call.errors = e.message
    end

    def incoming_mapping_ids
      project_ids = projects.pluck(:id)
      project_ids - existing_project_mappings(project_ids)
    end

    def projects
      [@project].tap do |projects_array|
        projects_array.concat(@project.active_subprojects.to_a) if @include_sub_projects
      end
    end

    def existing_project_mappings(project_ids)
      ProjectCustomFieldProjectMapping.where(
        custom_field_id: @project_custom_field.id,
        project_id: project_ids
      ).pluck(:project_id)
    end

    def set_attributes(params)
      attributes_service_class
        .new(user: @user,
             model: instance(params),
             contract_class: default_contract_class,
             contract_options: {})
        .call(params)
    end

    def instance(params)
      ProjectCustomFieldProjectMapping.new(params)
    end

    def attributes_service_class
      ProjectCustomFieldProjectMappings::SetAttributesService
    end

    def default_contract_class
      ProjectCustomFieldProjectMappings::UpdateContract
    end
  end
end
