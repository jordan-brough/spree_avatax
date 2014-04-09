module Spree
  Order.class_eval do

    Spree::Order.state_machine.after_transition :to => :complete, :do => :commit_avatax_invoice

    def doc_type
      'SalesInvoice'
    end

    def status_field
      :avatax_invoice_at
    end

    def build_line_items(order)
      # Only send the line items that return true for avataxable
      order.line_items.select do |line_item|
        line_item.avataxable?
      end
    end

    ##
    # This method sends an invoice to Avalara which is stored in their system.
    def commit_avatax_invoice
      SpreeAvatax::AvataxComputer.new.compute_order_with_context(self, self)
    end

    ##
    # Calculates the total discount of all eligible promotions for Avatax Discount
    # http://developer.avalara.com/api-docs/avalara-avatax-api-reference
    #
    def promotion_adjustment_total 
      return 0 if adjustments.nil?
      total = adjustments.map { |i| i.eligible? && i.originator_type == "Spree::PromotionAction" ? i.amount : BigDecimal("0.00") }.sum
      total.abs.round(2).to_f
    end
  end
end
