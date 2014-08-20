require 'avatax_taxservice'

class SpreeAvatax::ReturnInvoice < ActiveRecord::Base
  DOC_TYPE = 'ReturnInvoice'

  ADDRESS_CODE = "1"

  ORIGIN_CODE = "1"
  DESTINATION_CODE = "1"

  TAX_OVERRIDE_TYPE = 'TaxDate'
  TAX_OVERRIDE_REASON = 'Adjustment for return'

  class AvataxApiError < StandardError; end
  class AlreadyCommittedError < StandardError; end

  class_attribute :avatax_logger
  self.avatax_logger = Logger.new(Rails.root.join('log/avatax.log'))

  belongs_to :reimbursement, class_name: "Spree::Reimbursement"

  validates :reimbursement, presence: true
  validates :committed, inclusion: {in: [true, false], message: "must be true or false"}
  # these are values we need for the post_tax call
  validates(
    :doc_id, :doc_code, :doc_date, :pre_tax_total, :additional_tax_total,
    presence: true
  )

  class << self
    # Calls the Avatax API to generate a return invoice and calculate taxes on the return items.
    # On failure it will raise.
    # On success it will update the tax amounts on each return item and create a ReturnInvoice record.
    #   At this point an uncommitted return invoice has been created on Avatax's side.
    # After the reimbursement completes the ".finalize" method will get called and we'll commit the
    #   return invoice.
    def generate(reimbursement)
      success_result = get_tax(reimbursement)

      if reimbursement.return_invoice
        if reimbursement.return_invoice.committed?
          raise AlreadyCommittedError.new("Return invoice #{reimbursement.return_invoice.id} is already committed.")
        else
          reimbursement.return_invoice.destroy
        end
      end

      reimbursement.create_return_invoice!({
        committed:             false,
        doc_id:                success_result[:doc_id],
        doc_code:              success_result[:doc_code],
        doc_date:              success_result[:doc_date],
        pre_tax_total:         success_result[:total_amount],
        additional_tax_total:  success_result[:total_tax],
      })
    end

    # Commit the return invoice on Avatax's side after the reimbursement completes.
    # On failure it will raise.
    # On success it markes the invoice as committed.
    def finalize(reimbursement)
      post_tax(reimbursement.return_invoice)

      reimbursement.return_invoice.update!(committed: true)
    end

    private

    def get_tax(reimbursement)
      params = get_tax_params(reimbursement)

      avatax_logger.info "AVATAX_REQUEST context=get_tax reimbursement_id=#{reimbursement.id}"
      avatax_logger.debug params.to_json

      result = tax_svc.gettax(params)
      require_success!(result, reimbursement, 'get_tax')

      result
    end

    def post_tax(return_invoice)
      params = post_tax_params(return_invoice)

      avatax_logger.info "AVATAX_REQUEST context=post_tax reimbursement_id=#{return_invoice.reimbursement.id} return_invoice_id=#{return_invoice.id}"
      avatax_logger.debug params.to_json

      result = tax_svc.posttax(params)
      require_success!(result, return_invoice.reimbursement, 'post_tax')

      result
    end

    def require_success!(result, reimbursement, context)
      if result[:result_code] == 'Success'
        avatax_logger.info "AVATAX_RESPONSE context=#{context} result=success reimbursement_id=#{reimbursement.id} doc_id=#{result[:doc_id]}"
        avatax_logger.debug result.to_json
      else
        avatax_logger.error "AVATAX_RESPONSE context=#{context} result=error reimbursement_id=#{reimbursement.id} doc_id=#{result[:doc_id]}"
        avatax_logger.error result.to_json

        raise AvataxApiError.new("#{context} error: #{result[:messages]}")
      end
    end

    # see https://github.com/avadev/AvaTax-Calc-SOAP-Ruby/blob/master/GetTaxTest.rb
    def get_tax_params(reimbursement)
      {
        doccode:       reimbursement.number,
        referencecode: reimbursement.order.number,
        customercode:  reimbursement.order.user_id,
        companycode:   SpreeAvatax::Config.company_code,

        doctype: DOC_TYPE,
        docdate: Date.today,

        commit: false, # we commit after the reimbursement succeeds

        # These fields let Avatax know to use a different date for calculating tax
        taxoverridetype: TAX_OVERRIDE_TYPE,
        reason:          TAX_OVERRIDE_REASON,
        taxdate:         reimbursement.order.avatax_invoice_at.try(:to_date) || reimbursement.order.completed_at.to_date,

        addresses: [
          {
            addresscode: ADDRESS_CODE,
            line1:       reimbursement.order.ship_address.address1,
            line2:       reimbursement.order.ship_address.address2,
            city:        reimbursement.order.ship_address.city,
            postalcode:  reimbursement.order.ship_address.zipcode,
          },
        ],

        lines: get_tax_line_params(reimbursement),
      }
    end

    def get_tax_line_params(reimbursement)
      return_items = reimbursement.return_items.includes(inventory_unit: {line_item: {variant: :product}})

      return_items.map do |return_item|
        {
          # Required Parameters
          no:                  return_item.id,
          itemcode:            return_item.inventory_unit.line_item.variant.sku,
          qty:                 1,
          amount:              -return_item.pre_tax_amount,
          origincodeline:      ORIGIN_CODE,
          destinationcodeline: DESTINATION_CODE,

          # Best Practice Parameters
          description: return_item.inventory_unit.line_item.variant.product.description.to_s[0...100],
        }
      end
    end

    # see https://github.com/avadev/AvaTax-Calc-SOAP-Ruby/blob/master/PostTaxTest.rb
    def post_tax_params(return_invoice)
      {
        doccode:     return_invoice.doc_code,
        companycode: SpreeAvatax::Config.company_code,

        doctype: DOC_TYPE,
        docdate: return_invoice.doc_date,

        commit: true,

        totalamount: return_invoice.pre_tax_total,
        totaltax:    return_invoice.additional_tax_total,
      }
    end

    def tax_svc
      @tax_svc ||= AvaTax::TaxService.new({
        username:               SpreeAvatax::Config.username,
        password:               SpreeAvatax::Config.password,
        use_production_account: SpreeAvatax::Config.use_production_account,
        clientname:             'Spree::Avatax',
      })
    end
  end
end
