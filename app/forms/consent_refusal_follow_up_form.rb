# frozen_string_literal: true

class ConsentRefusalFollowUpForm
  include RequestSessionPersistable
  include WizardStepConcern

  def request_session_key = "follow_up_refusal"

  attribute :decision_stands, :string
  attribute :confirmed, :string
  attribute :notes, :string

  def wizard_steps = %i[follow_up confirm_refusal]

  on_wizard_step :follow_up do
    validates :decision_stands, inclusion: { in: %w[true false] }
  end

  on_wizard_step :confirm_refusal do
    validates :confirmed, inclusion: { in: %w[true false] }
    validates :notes, length: { maximum: 1000 }
  end

  def decision_stands? = decision_stands == "true"

  def confirmed? = confirmed == "true"
end
