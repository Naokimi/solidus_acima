require 'spec_helper'
require 'httparty'

RSpec.describe SolidusAcima::Gateway, type: :model do
  let(:gateway)        { described_class.new({ test_mode: true }) }
  let(:payment_source) { create(:acima_payment_source) }
  let(:payment)        { create(:acima_payment) }

  describe '#generate_bearer_token' do
    let(:api_response) { double(HTTParty) } # rubocop:disable RSpec/VerifiedDoubles

    before { allow(HTTParty).to receive(:post).and_return(api_response) }

    context 'when successful' do
      let(:bearer_token) { 'abc' }

      before do
        allow(api_response).to receive(:success?).and_return(true)
        allow(api_response).to receive(:[]).and_return(bearer_token)
      end

      it 'generates a bearer token' do
        expect(gateway.acima_bearer_token).to eq(bearer_token)
      end
    end

    context 'when failed' do
      before { allow(api_response).to receive(:success?).and_return(false) }

      it 'raises and error' do
        expect { gateway }.to raise_error(RuntimeError, /Acima Server Response Error:/)
      end
    end
  end

  context 'with stubbed authorization step' do
    before { allow_any_instance_of(described_class).to receive(:generate_bearer_token).and_return('abc') } # rubocop:disable RSpec/AnyInstance

    describe '#initialize' do
      it 'initializes' do
        expect(gateway).to be_an_instance_of(described_class)
      end
    end

    describe '#authorize' do
      subject(:authorize_response) { gateway.authorize(nil, payment_source, {}) }

      it 'successfully returns a response' do
        expect(authorize_response).to be_an_instance_of(ActiveMerchant::Billing::Response)
      end
    end

    describe '#capture' do
      subject(:capture_response) { gateway.capture(nil, payment_source.checkout_token, { originator: payment }) }

      let(:api_response) { double(HTTParty) } # rubocop:disable RSpec/VerifiedDoubles

      before do
        payment.order.update(state: 'complete')
        payment.update(state: 'pending')
        allow(HTTParty).to receive(:put).and_return(api_response)
        allow(api_response).to receive(:stringify_keys).and_return('')
      end

      context 'when successful' do
        before { allow(api_response).to receive(:success?).and_return(true) }

        it 'creates a billing response' do
          expect(capture_response.class).to eq(ActiveMerchant::Billing::Response)
        end

        it 'the response returns true on #success?' do
          expect(capture_response.success?).to eq(true)
        end
      end

      context 'when failed' do # rubocop:disable RSpec/NestedGroups
        before do
          allow(api_response).to receive(:success?).and_return(false)
          allow(api_response).to receive(:code).and_return(415)
        end

        it 'creates a failed billing response' do
          expect(capture_response.class).to eq(ActiveMerchant::Billing::Response)
        end

        it 'the response returns false on #success?' do
          expect(capture_response.success?).to eq(false)
        end
      end
    end

    describe '#purchase' do
      subject(:purchase_response) { gateway.purchase(nil, payment_source.checkout_token, { originator: payment }) }

      let(:api_response) { double(HTTParty) } # rubocop:disable RSpec/VerifiedDoubles

      before do
        payment.order.update(state: 'complete')
        payment.update(state: 'pending')
        allow(HTTParty).to receive(:put).and_return(api_response)
        allow(api_response).to receive(:stringify_keys).and_return('')
      end

      context 'when successful' do # rubocop:disable RSpec/NestedGroups
        before { allow(api_response).to receive(:success?).and_return(true) }

        it 'creates a billing response' do
          expect(purchase_response.class).to eq(ActiveMerchant::Billing::Response)
        end

        it 'the response returns true on #success?' do
          expect(purchase_response.success?).to eq(true)
        end
      end

      context 'when failed' do # rubocop:disable RSpec/NestedGroups
        before do
          allow(api_response).to receive(:success?).and_return(false)
          allow(api_response).to receive(:code).and_return(415)
        end

        it 'creates a failed billing response' do
          expect(purchase_response.class).to eq(ActiveMerchant::Billing::Response)
        end

        it 'the response returns false on #success?' do
          expect(purchase_response.success?).to eq(false)
        end
      end
    end

    describe '#void' do
      subject(:void_response) { gateway.void(payment_source.checkout_token, { originator: payment }) }

      let(:api_response) { double(HTTParty) } # rubocop:disable RSpec/VerifiedDoubles

      before do
        payment.order.update(state: 'complete')
        payment.update(state: 'pending')
        allow(HTTParty).to receive(:post).and_return(api_response)
        allow(api_response).to receive(:stringify_keys).and_return('')
      end

      context 'when successful' do # rubocop:disable RSpec/NestedGroups
        before { allow(api_response).to receive(:success?).and_return(true) }

        it 'creates a billing response' do
          expect(void_response.class).to eq(ActiveMerchant::Billing::Response)
        end

        it 'the response returns true on #success?' do
          expect(void_response.success?).to eq(true)
        end
      end

      context 'when failed' do # rubocop:disable RSpec/NestedGroups
        before do
          allow(api_response).to receive(:success?).and_return(false)
          allow(api_response).to receive(:code).and_return(415)
        end

        it 'raises an error' do
          expect { void_response }.to raise_error(RuntimeError, /Acima Server Response Error:/)
        end
      end
    end

    describe '#credit' do
      subject(:credit_response) { gateway.credit(nil, payment_source.checkout_token, { originator: refund }) }

      let(:refund) { build(:refund, payment: payment) }

      before do
        payment.order.update(state: 'complete')
        payment.update(state: 'pending')
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(described_class).to receive(:acima_payment_captured?).and_return(acima_response)
        # rubocop:enable RSpec/AnyInstance
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers
      context 'with payment captured by Acima' do # rubocop:disable RSpec/NestedGroups
        let(:acima_response) { true }
        let(:api_response)   { double(HTTParty) } # rubocop:disable RSpec/VerifiedDoubles

        before do
          allow(HTTParty).to receive(:post).and_return(api_response)
          allow(api_response).to receive(:stringify_keys).and_return('')
        end

        context 'when successful' do # rubocop:disable RSpec/NestedGroups
          before { allow(api_response).to receive(:success?).and_return(true) }

          it 'creates a billing response' do
            expect(credit_response.class).to eq(ActiveMerchant::Billing::Response)
          end

          it 'the response returns true on #success?' do
            expect(credit_response.success?).to eq(true)
          end
        end


        context 'when failed' do # rubocop:disable RSpec/NestedGroups
          before do
            allow(api_response).to receive(:success?).and_return(false)
            allow(api_response).to receive(:code).and_return(415)
          end

          it 'raises an error' do
            expect { credit_response }.to raise_error(RuntimeError, /Acima Server Response Error:/)
          end
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'without payment captured by Acima' do # rubocop:disable RSpec/NestedGroups
        let(:acima_response) { false }

        before { allow_any_instance_of(described_class).to receive(:void) } # rubocop:disable RSpec/AnyInstance

        it 'calls #void' do
          expect_any_instance_of(described_class).to receive(:void) # rubocop:disable RSpec/AnyInstance
          credit_response
        end
      end
    end
  end
end
