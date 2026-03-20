# frozen_string_literal: true

class AppPatientSessionRecordComponent < ViewComponent::Base
  def initialize(patient:, session:, programme:, current_user:, vaccinate_form:)
    @patient = patient
    @session = session
    @programme = programme
    @current_user = current_user
    @vaccinate_form = vaccinate_form || default_vaccinate_form
  end

  def render?
    session.today? &&
      patient.consent_given_and_safe_to_vaccinate?(
        programme:,
        academic_year:
      ) && can_record_today?
  end

  private

  attr_reader :patient, :session, :current_user, :programme, :vaccinate_form

  delegate :policy, to: :helpers
  delegate :academic_year, :team, to: :session

  def url
    session_patient_programme_vaccinations_path(session, patient, programme)
  end

  def vaccination_record
    VaccinationRecord.new(patient:, session:, programme:)
  end

  def vaccine_criteria
    @vaccine_criteria ||= patient.vaccine_criteria(programme:, academic_year:)
  end

  def vaccine_methods
    @vaccine_methods ||=
      begin
        approved_vaccine_methods = vaccine_criteria.vaccine_methods

        if current_user.is_nurse? || current_user.is_prescriber?
          return approved_vaccine_methods
        end
        return [] unless healthcare_assistant?

        approved_vaccine_methods.select do |vaccine_method|
          (
            vaccine_method == "injection" && session.national_protocol_enabled?
          ) || (vaccine_method == "nasal" && session.pgd_supply_enabled?) ||
            (
              session.psd_enabled? &&
                patient.has_patient_specific_direction?(
                  academic_year:,
                  programme_type: programme.type,
                  team:,
                  vaccine_method:
                )
            )
        end
      end
  end

  def show_supplied_by_user_id_outside_vaccine_method?
    @show_supplied_by_user_id_outside_vaccine_method ||=
      healthcare_assistant? &&
        vaccine_methods.none? do |vaccine_method|
          has_patient_specific_direction?(vaccine_method:)
        end
  end

  def show_supplied_by_user_id_inside_vaccine_method?(vaccine_method)
    return false if show_supplied_by_user_id_outside_vaccine_method?

    healthcare_assistant? && !has_patient_specific_direction?(vaccine_method:)
  end

  def has_patient_specific_direction?(vaccine_method:)
    session.psd_enabled? &&
      patient.has_patient_specific_direction?(
        academic_year:,
        programme_type: programme.type,
        team:,
        vaccine_method:
      )
  end

  def healthcare_assistant? = current_user.is_healthcare_assistant?

  def dose_sequence
    patient.programme_status(programme, academic_year:).dose_sequence
  end

  COMMON_DELIVERY_SITES = {
    "injection" => %w[left_arm_upper_position right_arm_upper_position],
    "nasal" => %w[nose]
  }.freeze

  CommonDeliverySite = Struct.new(:value, :label)

  def common_delivery_site_options(vaccine_method)
    common_delivery_sites = COMMON_DELIVERY_SITES.fetch(vaccine_method)

    options =
      common_delivery_sites.map do |value|
        label = VaccinationRecord.human_enum_name(:delivery_site, value)
        CommonDeliverySite.new(value:, label:)
      end

    has_more_delivery_sites =
      (
        Vaccine::AVAILABLE_DELIVERY_SITES.fetch(vaccine_method) -
          common_delivery_sites
      ).present?

    if has_more_delivery_sites
      options << CommonDeliverySite.new(value: "other", label: "Other")
    end

    options
  end

  def vaccination_name
    vaccination =
      if programme.has_multiple_vaccine_methods?
        Vaccine.human_enum_name(:method, vaccine_methods.first).downcase
      else
        "vaccination"
      end

    "#{programme.name_in_sentence} #{vaccination}"
  end

  def ask_not_taking_medication? = programme.doubles? || programme.flu?

  def ask_not_pregnant? = programme.td_ipv?

  def ask_asthma_flare_up? = vaccine_methods.include?("nasal")

  def can_record_today?
    return true unless session.requires_registration?

    today_attendance_record.present? && today_attendance_record&.attending?
  end

  def today_attendance_record
    patient.attendance_records.find do |attendance_record|
      attendance_record.location_id == session.location_id &&
        attendance_record.date == Date.current
    end
  end

  def default_vaccinate_form
    pre_screening_confirmed =
      patient.pre_screenings.today.for_programme(programme).exists?

    VaccinateForm.new(
      current_user:,
      patient:,
      session:,
      programme:,
      pre_screening_confirmed:
    )
  end

  def heading
    vaccine_criteria = patient.vaccine_criteria(programme:, academic_year:)
    render AppVaccineCriteriaLabelComponent.new(
             vaccine_criteria,
             programme:,
             context: :heading
           )
  end
end
