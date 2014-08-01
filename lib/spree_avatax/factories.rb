#
# Adding this to your spec_helper will load these Factories for use:
#   require 'spree_avatax/factories'
#

FactoryGirl.define do
  sequence(:doc_id) { |n| n.to_s.rjust(16, '0') }

  factory :return_invoice, class: SpreeAvatax::ReturnInvoice do
    association :reimbursement
    committed false
    doc_id { generate(:doc_id) }
    doc_code { reimbursement.number }
    doc_date { reimbursement.order.avatax_invoice_at.try(:to_date) || reimbursement.order.completed_at.to_date }
    pre_tax_total { reimbursement.return_items.sum(:pre_tax_amount) }
    additional_tax_total { reimbursement.return_items.sum(:additional_tax_total) }
  end
end
