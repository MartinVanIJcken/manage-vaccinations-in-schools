# frozen_string_literal: true

describe ConsentRefusalFollowUpForm do
  subject(:form) { described_class.new(request_session:) }

  let(:request_session) { {} }

  def valid_for_step?(form)
    form.valid?(:update)
  end

  describe "follow_up step" do
    before { form.wizard_step = :follow_up }

    it "is invalid without decision_stands" do
      expect(valid_for_step?(form)).to be false
    end

    context "with decision_stands set to true" do
      before { form.decision_stands = "true" }

      it "is valid" do
        expect(valid_for_step?(form)).to be true
      end
    end

    context "with decision_stands set to false" do
      before { form.decision_stands = "false" }

      it "is valid" do
        expect(valid_for_step?(form)).to be true
      end
    end

    context "with an invalid decision_stands value" do
      before { form.decision_stands = "maybe" }

      it "is invalid" do
        expect(valid_for_step?(form)).to be false
      end
    end
  end

  describe "confirm_refusal step" do
    before do
      form.wizard_step = :confirm_refusal
      form.decision_stands = "true"
    end

    context "with confirmed set to true" do
      before { form.confirmed = "true" }

      it "is valid" do
        expect(valid_for_step?(form)).to be true
      end
    end

    context "with confirmed set to false" do
      before { form.confirmed = "false" }

      it "is valid" do
        expect(valid_for_step?(form)).to be true
      end
    end

    context "without confirmed" do
      it "is invalid" do
        expect(valid_for_step?(form)).to be false
      end
    end

    context "with notes exceeding 1000 characters" do
      before do
        form.confirmed = "true"
        form.notes = "a" * 1001
      end

      it "is invalid" do
        expect(valid_for_step?(form)).to be false
      end
    end

    context "with notes at exactly 1000 characters" do
      before do
        form.confirmed = "true"
        form.notes = "a" * 1000
      end

      it "is valid" do
        expect(valid_for_step?(form)).to be true
      end
    end
  end

  describe "#decision_stands?" do
    it "returns true when decision_stands is 'true'" do
      form.decision_stands = "true"
      expect(form.decision_stands?).to be true
    end

    it "returns false when decision_stands is 'false'" do
      form.decision_stands = "false"
      expect(form.decision_stands?).to be false
    end

    it "returns false when decision_stands is nil" do
      expect(form.decision_stands?).to be false
    end
  end

  describe "#confirmed?" do
    it "returns true when confirmed is 'true'" do
      form.confirmed = "true"
      expect(form.confirmed?).to be true
    end

    it "returns false when confirmed is 'false'" do
      form.confirmed = "false"
      expect(form.confirmed?).to be false
    end

    it "returns false when confirmed is nil" do
      expect(form.confirmed?).to be false
    end
  end
end
