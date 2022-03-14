# frozen_string_literal: true

require 'httparty'

module SolidusAcima
  class Gateway
    attr_reader :api_url, :acima_bearer_token

    def initialize(options)
      sandbox = options[:iframe_url].include?('sandbox') ? '-sandbox' : ''
      @api_url = "https://api#{sandbox}.acimacredit.com/api"
      @acima_bearer_token = generate_bearer_token(options[:client_id], options[:client_secret])
    end

    def authorize(_amount, payment_source, _options)
      ActiveMerchant::Billing::Response.new(
        true,
        'Transaction approved',
        payment_source.attributes,
        authorization: payment_source.checkout_token
      )
    end

    def capture(_amount, response_code, options)
      source = options[:originator].source

      url = "#{api_url}/contracts/#{source.lease_id}/delivery_confirmation"
      headers = {
        'Authorization': "Bearer #{acima_bearer_token}",
        'Accept': 'application/vnd.acima-v2+json',
        'Content-Type': 'application/json'
      }
      body = { selected_delivery_date: Time.zone.tomorrow.strftime("%F") }.to_json
      response = HTTParty.put(url, headers: headers, body: body)

      if response.success?
        ActiveMerchant::Billing::Response.new(
          true,
          'Transaction captured',
          response || {},
          authorization: response_code
        )
      else
        ActiveMerchant::Billing::Response.new(
          false,
          'Transaction error',
          response || {},
          error_code: response.code
        )
      end
    end

    def purchase(amount, response_code, options)
      capture(amount, response_code, options)
    end

    def void(response_code, options)
      payment_source = options[:originator].source

      url = "#{api_url}/applications/#{payment_source.lease_id}/cancel"
      headers = { 'Authorization': "Bearer #{acima_bearer_token}", 'Accept': 'application/vnd.acima-v2+json' }
      response = HTTParty.post(url, headers: headers)

      raise 'Acima Server Response Error: Did not get correct response code' unless response.success?

      ActiveMerchant::Billing::Response.new(
        true,
        'Transaction voided',
        {},
        authorization: response_code
      )
    end

    private

    def generate_bearer_token(client_id, client_secret)
      url = "#{api_url}/oauth/token"
      headers = { 'Content-Type': 'application/json' }
      body = {
        client_id: client_id,
        client_secret: client_secret,
        audience: 'https://aperture.acimacredit.com',
        grant_type: 'client_credentials'
      }.to_json

      response = HTTParty.post(url, headers: headers, body: body)

      raise "Acima Server Response Error: #{response}" unless response.success?

      response['access_token']
    end
  end
end
