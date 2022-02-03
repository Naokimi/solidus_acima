# frozen_string_literal: true

module SolidusAcima
  module CheckoutControllerDecorator
    def self.prepended(base)
      base.helper ::SolidusAcima::CheckoutHelper
    end

    ::Spree::CheckoutController.prepend(self) if SolidusSupport.frontend_available?
    ::Spree::Admin::PaymentsController.prepend(self) if SolidusSupport.backend_available?
  end
end
