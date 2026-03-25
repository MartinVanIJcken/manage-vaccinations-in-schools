# frozen_string_literal: true

class EnqueueBulkRemoveVaccinationRecordsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform(import_id)
    import = ImmunisationImport.find(import_id)
    return unless import

    import
      .vaccination_record_ids
      .each_slice(BATCH_SIZE) do |batch_ids|
        BulkRemoveVaccinationRecordsJob.perform_later(import_id, batch_ids)
      end
  end
end
