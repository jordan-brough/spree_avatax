# Avatax Setup
SpreeAvatax::Config.username = 'your avatax username'
SpreeAvatax::Config.password = 'your avatax password'
SpreeAvatax::Config.company_code = 'your avatax company code'
SpreeAvatax::Config.use_production_url = Rails.env.production?
# The "endpoint" config will soon be replaced by the "use_production_url" config
SpreeAvatax::Config.endpoint = Rails.env.production? ? 'https://avatax.avalara.net/': 'https://development.avalara.net/'

# Use Avatax to compute return invoice tax amounts
Spree::Reimbursement.reimbursement_tax_calculator = lambda do |reimbursement|
  SpreeAvatax::ReturnInvoice.generate(reimbursement)
end
# Finalize the avatax return invoice after a reimubursement completes successfully
Spree::Reimbursement.reimbursement_success_hooks << lambda do |reimbursement|
  SpreeAvatax::ReturnInvoice.finalize(reimbursement)
end
