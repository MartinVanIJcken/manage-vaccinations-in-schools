# frozen_string_literal: true

describe AppPatientSessionRecordComponent do
  subject { render_inline(component) }

  let(:component) do
    described_class.new(
      patient:,
      session:,
      programme:,
      current_user:,
      vaccinate_form:
    )
  end

  let(:team) { create(:team, programmes:) }
  let(:current_user) { create(:user, team:) }
  let(:programme) { Programme.hpv }
  let(:programmes) { [programme] }
  let(:session) { create(:session, :today, team:, programmes:) }
  let(:patient) do
    create(
      :patient,
      :consent_given_triage_not_needed,
      :in_attendance,
      session:,
      given_name: "Hari"
    )
  end
  let(:vaccinate_form) do
    VaccinateForm.new(current_user:, patient:, session:, programme:)
  end

  describe "#render?" do
    subject { component.render? }

    it { should be(true) }

    context "patient is not ready for vaccination" do
      let(:patient) { create(:patient, programmes:) }

      it { should be(false) }
    end

    context "patient is not attending the session" do
      let(:patient) do
        create(:patient, :consent_given_triage_not_needed, session:)
      end

      it { should be(false) }
    end

    context "patient attended the session yesterday but not marked as attending today" do
      let(:session) do
        create(
          :session,
          team:,
          programmes:,
          dates: [Date.yesterday, Date.current]
        )
      end

      let(:patient) do
        create(:patient, :consent_given_triage_not_needed, session:)
      end

      before do
        create(
          :attendance_record,
          patient:,
          location: session.location,
          date: Date.yesterday,
          attending: true
        )

        create(:patient_registration_status, :completed, patient:, session:)
      end

      it { should be(false) }
    end

    context "patient is fully vaccinated" do
      let(:patient) { create(:patient, :vaccinated, programmes:) }

      before do
        create(:patient_registration_status, :completed, patient:, session:)
      end

      it { should be(false) }

      context "but the session was yesterday" do
        let(:session) { create(:session, :yesterday, team:, programmes:) }

        it { should be(false) }
      end
    end

    context "session requires no registration" do
      let(:session) do
        create(:session, :requires_no_registration, team:, programmes:)
      end

      it { should be(true) }

      context "but the session was yesterday" do
        let(:session) { create(:session, :yesterday, team:, programmes:) }

        it { should be(false) }
      end
    end
  end

  describe "#render" do
    before do
      stub_authorization(allowed: true)
      patient.programme_status(
        programme,
        academic_year: session.academic_year
      ).assign
    end

    it { should have_heading("Record HPV vaccination") }
    it { should have_content("Has Hari confirmed their identity?") }
    it { should have_field("No, it was confirmed by somebody else") }

    context "with a flu programme" do
      let(:programme) { Programme.flu }

      it { should have_text("Is Hari ready for their flu injection?") }
      it { should have_field("Yes") }
      it { should have_field("No") }
      it { should have_field("Left arm (upper position)") }
      it { should have_field("Right arm (upper position)") }
      it { should_not have_field("Nose") }
      it { should have_field("Other") }
    end

    context "with a flu programme and consent to nasal spray only" do
      let(:programme) { Programme.flu }

      let(:patient) do
        create(
          :patient,
          :consent_given_nasal_only_triage_not_needed,
          :in_attendance,
          session:,
          given_name: "Hari"
        )
      end

      it { should have_text("Is Hari ready for their flu nasal spray?") }
      it { should have_field("Yes") }
      it { should have_field("No") }
      it { should_not have_field("Left arm (upper position)") }
      it { should_not have_field("Right arm (upper position)") }
      it { should_not have_field("Nose") }
      it { should_not have_field("Other") }
    end

    context "with a flu programme, consent to nasal spray, but triaged for injection" do
      let(:programme) { Programme.flu }

      let(:patient) do
        create(
          :patient,
          :consent_given_injection_and_nasal_triage_safe_to_vaccinate_injection,
          :in_attendance,
          session:,
          given_name: "Hari"
        )
      end

      it { should have_text("Is Hari ready for their flu injection?") }
      it { should have_field("Left arm (upper position)") }
      it { should have_field("Right arm (upper position)") }
      it { should_not have_field("Nose") }
      it { should have_field("Other") }
    end

    context "with an HPV programme" do
      it { should have_text("Is Hari ready for their HPV vaccination?") }
      it { should have_field("Left arm (upper position)") }
      it { should have_field("Right arm (upper position)") }
      it { should_not have_field("Nose") }
      it { should have_field("Other") }
    end
  end

  describe "#dose_sequence" do
    subject { component.send(:dose_sequence) }

    let(:prior_vaccination_records) { nil }

    before do
      prior_vaccination_records # create any prior records before assigning status
      patient.programme_status(
        programme,
        academic_year: session.academic_year
      ).assign
    end

    context "with HPV programme" do
      let(:programme) { Programme.hpv }

      it { should eq(1) }
    end

    context "with Td/IPV programme" do
      let(:programme) { Programme.td_ipv }

      it { should eq(5) }
    end

    context "with MenACWY programme" do
      let(:programme) { Programme.menacwy }

      it { should eq(1) }
    end

    context "with flu programme" do
      let(:programme) { Programme.flu }

      it { should eq(1) }
    end

    context "with MMR programme" do
      let(:programme) { Programme.mmr }

      it { should eq(1) }

      context "with an existing vaccination record" do
        let(:prior_vaccination_records) do
          create(:vaccination_record, patient:, programme:, dose_sequence: 1)
        end

        it { should eq(2) }
      end
    end
  end
end
