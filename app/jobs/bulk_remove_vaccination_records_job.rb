# frozen_string_literal: true

class BulkRemoveVaccinationRecordsJob < ApplicationJob
  queue_as :imports

  def perform(import_id, vaccination_records_batch_ids)
    import = ImmunisationImport.find(import_id)
    return unless import

    ActiveRecord::Base.transaction do
      vrs =
        import
          .vaccination_records
          .where(id: vaccination_records_batch_ids)
          .includes(:immunisation_imports)

      exclusive_vrs, shared_vrs =
        vrs.partition { |vr| vr.immunisation_imports.count == 1 }

      VaccinationRecord.where(id: exclusive_vrs.map(&:id)).destroy_all
      import.vaccination_records.delete(shared_vrs)

      Rails.logger.info(
        "Deleted #{exclusive_vrs.size} vaccination records and unlinked " \
          "#{shared_vrs.size} shared records from immunisation import #{import.id}"
      )
    end
  end
end
