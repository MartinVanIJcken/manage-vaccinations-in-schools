# frozen_string_literal: true

describe EnqueueBulkRemoveVaccinationRecordsJob do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.new.perform(import.id) }

  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:user) { create(:user, team:) }
  let(:import) { create(:immunisation_import, team:, uploaded_by: user) }

  describe "#perform" do
    context "when the import has no vaccination records" do
      it "enqueues no batch jobs" do
        expect { perform_job }.not_to have_enqueued_job(
          BulkRemoveVaccinationRecordsJob
        )
      end
    end

    context "when the import has fewer records than the batch size" do
      before do
        3.times do
          vr = create(:vaccination_record, programme:)
          import.vaccination_records << vr
        end
      end

      it "enqueues a single batch job" do
        expect { perform_job }.to have_enqueued_job(
          BulkRemoveVaccinationRecordsJob
        ).exactly(:once)
      end

      it "passes the import id and all vaccination record ids to the batch job" do
        perform_job
        expect(BulkRemoveVaccinationRecordsJob).to have_been_enqueued.with(
          import.id,
          import.vaccination_record_ids
        )
      end
    end

    context "when the import has more records than the batch size" do
      before do
        stub_const("EnqueueBulkRemoveVaccinationRecordsJob::BATCH_SIZE", 2)
        3.times do
          vr = create(:vaccination_record, programme:)
          import.vaccination_records << vr
        end
      end

      it "enqueues one batch job per slice" do
        expect { perform_job }.to have_enqueued_job(
          BulkRemoveVaccinationRecordsJob
        ).exactly(2).times
      end

      it "enqueues jobs on the imports queue" do
        perform_job
        expect(BulkRemoveVaccinationRecordsJob).to have_been_enqueued.on_queue(
          "imports"
        )
      end
    end
  end
end
