class Household < ActiveRecord::Base

  include BooleanRender
  include HouseholdDataChecker
  include HouseholdReport

  attr_accessor :matching_address

  DistributionColorCodes = ['','red','yellow','green','purple','blue','gray'] # indexed by number of residents

  has_many :clients
  has_many :distributions, :dependent => :destroy, :autosave => true
  has_many :household_checkins, :dependent => :destroy, :autosave => true

  with_options :dependent => :destroy, :autosave => true do |h|
    [:perm_address, :temp_address].each{|pt| h.belongs_to pt}
  end
  accepts_nested_attributes_for :perm_address, :temp_address

  with_options :foreign_key => :association_id, :dependent => :destroy, :autosave => true do |h|
    [:res_qualdoc, :inc_qualdoc, :gov_qualdoc].each{|t| h.has_one t}
  end
  accepts_nested_attributes_for :res_qualdoc, :inc_qualdoc, :gov_qualdoc

  [:address, :city, :zip, :apt, :address=, :city=, :zip=, :apt=].each do |attr|
    delegate attr, :to => :perm_address, :prefix => :permanent, :allow_nil => true
    delegate attr, :to => :temp_address, :prefix => :temporary, :allow_nil => true
  end

  [:upload_link_text, :qualification_error_message, :qualification_vector, :current?, :confirm, :warnings, :vi, :confirm=, :warnings=, :vi=].each do |attr|
    delegate attr, :to => :res_qualdoc, :prefix => :res, :allow_nil => true
    delegate attr, :to => :inc_qualdoc, :prefix => :inc, :allow_nil => true
    delegate attr, :to => :gov_qualdoc, :prefix => :gov, :allow_nil => true
  end

  delegate_multiparameter :date, :to => :res_qualdoc, :prefix => :res
  delegate_multiparameter :date, :to => :inc_qualdoc, :prefix => :inc
  delegate_multiparameter :date, :to => :gov_qualdoc, :prefix => :gov

  # type is either :temp or :perm, search_obj is an object of type HouseholdSearch
  scope :with_address_matching, lambda{|type, search_obj | matching_fields(type, search_obj) }


  # returns an ActiveRecord::Relation object
  # representing a database search for matches against
  # address (temp or perm) and clients
  def self.matching_fields(type, household_search)
    a = select(['households.id', :"#{type}_address_id"])
    b = matching_address(type, household_search) if household_search.has_address_params?
    c = matching_clients(household_search) if household_search.has_client_params?
    [a,b,c].compact.inject{|x,y| x.merge y} # here compact means tables are searched only if parameters are provided
  end

  # returns an ActiveRecord::Relation object, or nil if no relevant parameters are provided
  # representing database search for matching addresses
  def self.matching_address(type, household_search)
    table = "#{type}_address" # e.g. "perm_address"
    a = includes(:"#{table}")
    b = table.camelize.constantize.matching(household_search.params) # e.g. PermAddress
    a.merge b
  end

  # returns an ActiveRecord::Relation object, or nil if no relevant parameters are provided
  def self.matching_clients(household_search)
    includes(:clients).where("clients.lastName LIKE ?", "%#{ household_search.client_name }%")
  end

  def self.matching(household_search)
    unless household_search.blank?
      households = with_address_matching(:perm, household_search).each{|h| h.map_address_from(:perm_address)}
      households += with_address_matching(:temp, household_search).each{|h| h.map_address_from(:temp_address)}
      households.uniq
    end
  end

  validate do |household|
    errors.add(:base, "A household must have either a permanent or a temporary address") unless household.has_full_perm_or_temp_address?
  end

  # overwrite the ActiveModel method here and define the humanized attributes
  # in the model rather than in a locales file
  def self.human_attribute_name(attr, options = {})
    HumanizedAttributes[attr.to_sym] || super
  end

  # override the column attribute as it's often incorrect!
  def resident_count
    clients.size
  end

  def distribution_color_code
    DistributionColorCodes[[6,resident_count].min]
  end

  # returns true if either all perm address fields or all temp address fields are present
  def has_full_perm_or_temp_address?
    [(perm_address && perm_address.complete?), (temp_address && temp_address.complete?)].any?
  end

  # configures the parameter that controls delegation to either temp address or perm address
  # depending on which matched the search criteria
  def map_address_from(temp_or_perm)
    @matching_address = temp_or_perm
  end

  # methods are delegated either to perm_address or temp_address dynamically
  # depending on the value of @matching address
  [:address, :city, :zip, :has_po_box?, :has_po_box, :po_box_number, :street_name, :street_number].each do |attr| 
    define_method(attr) do
      if @matching_address && (add = self.send(@matching_address))
        add.send(attr)
      end
    end
  end

  def client_names
    clients.map(&:lastName).uniq.compact.sort.join(', ')
  end

  # returns information about any and all expired documentation for the
  # household and its clients. Used during client check in.
  def qualification(checkin_id = nil)
    client_checkin = ClientCheckin.find(checkin_id) if checkin_id
    household_checkin = HouseholdCheckin.find(client_checkin.household_checkin_id) if client_checkin
     [res_qualification_vector.merge({:warned => household_checkin && household_checkin.res_warn}),
      inc_qualification_vector.merge({:warned => household_checkin && household_checkin.inc_warn}),
      gov_qualification_vector.merge({:warned => household_checkin && household_checkin.gov_warn})]
  end

  def client_docs(checkin_id)
    clients.sort_by(&:age_or_zero).map{|c| c.id_qualification_vector(checkin_id)}.compact
  end

  def qualification_docs(checkin_id)
    qualification(checkin_id) + client_docs(checkin_id)
  end

  def with_errors
    has_client_errors? || has_household_errors?
  end

  def has_client_errors?
    !clients.map(&:id_current?).all?
  end

  def has_household_errors?
    ![res_current?, inc_current?, gov_current?].all?
  end

  def has_res_doc_in_db?
    res_qualdoc && res_qualdoc.in_db?
  end

  def has_inc_doc_in_db?
    inc_qualdoc && inc_qualdoc.in_db?
  end

  def has_gov_doc_in_db?
    gov_qualdoc && gov_qualdoc.in_db?
  end

  def res_doc_exists?
    res_qualdoc &&
      res_qualdoc.docfile &&
      res_qualdoc.docfile.current_path &&
      File.exists?(res_qualdoc.docfile.current_path)
  end

  def inc_doc_exists?
    inc_qualdoc &&
      inc_qualdoc.docfile &&
      inc_qualdoc.docfile.current_path &&
      File.exists?(inc_qualdoc.docfile.current_path)
  end

  def gov_doc_exists?
    gov_qualdoc &&
      gov_qualdoc.docfile &&
      gov_qualdoc.docfile.current_path &&
      File.exists?(gov_qualdoc.docfile.current_path)
  end

  def assign_as_sole_head(head_client)
    clients.each{|client|
      client.assign_as_head(client == head_client)
    }
  end

end
