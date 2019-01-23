module Bitmex
  # Account Operations
  #
  # All read-only operations to load user's data are implemented and work as described in docs.
  # Multiple PUT/POST endpoints return 'Access Denied' and are not implemented. It seems that they are meant to be used internally by BitMEX only.
  #
  # @author Iulian Costan
  class User
    attr_reader :client

    # @param client [Bitmex::Client] the HTTP client
    def initialize(client)
      @client = client
    end

    # Get your current affiliate/referral status.
    # @return [Hash] the affiliate status
    def affiliate_status
      get 'affiliateStatus'
    end

    # Check if a referral code is valid. If the code is valid, responds with the referral code's discount (e.g. 0.1 for 10%) and false otherwise
    # @param code [String] the referral code
    # @return [Decimal, nil] the discount or nil
    def check_referral_code(code)
      get 'checkReferralCode', referralCode: code do |response|
        return nil if !response.success? && [404, 451].include?(response.code)

        response.to_f
      end
    end

    # Get your account's commission status
    # @return [Hash] the commission by each product
    def commission
      get 'commission'
    end

    # Get a deposit address
    # @param currency [String] currency symbol
    # @return [String] the address
    def deposit_address(currency = 'XBt')
      get 'depositAddress', currency: currency do |response|
        fail response.body unless response.success?

        response.to_s
      end
    end

    # Get the execution history by day
    # @param symbol [String] the symbol to get the history for
    # @param timestamp [Datetime] the datetime to filter the history for
    # @return [Array] the history
    def execution_history(symbol = 'XBTUSD', timestamp = Date.today)
      get 'executionHistory', symbol: symbol, timestamp: timestamp
    end

    # Get your account's margin status
    # @param currency [String] the currency to filter by
    # @return [Hash] the margin
    def margin(currency = 'XBt')
      get 'margin', currency: currency
    end

    # Get the minimum withdrawal fee for a currency
    # This is changed based on network conditions to ensure timely withdrawals. During network congestion, this may be high. The fee is returned in the same currency.
    # @param currency [String] the currency to get the fee for
    # @return [Hash] the fee
    def min_withdrawal_fee(currency = 'XBt')
      get 'minWithdrawalFee', currency: currency
    end

    # Get your current wallet information
    # @return [Hash] the current wallet
    def wallet
      get 'wallet'
    end

    # Get a history of all of your wallet transactions (deposits, withdrawals, PNL)
    # @return [Array] the wallet history
    def wallet_history
      get 'walletHistory'
    end

    # Get a summary of all of your wallet transactions (deposits, withdrawals, PNL)
    # @return [Array] the wallet summary
    def wallet_summary
      get 'walletSummary'
    end

    # Get your user events
    # @return [Array] the events
    def events
      data = get '', resource: 'userEvent'
      data.userEvents
    end

    private

    def method_missing(m, *args, &ablock)
      if @data.nil?
        get '' do |response|
          fail response.body unless response.success?

          @data = Bitmex::Mash.new response
        end
      end
      @data.send m
    end

    def put(resource, params, &ablock)
      path = user_path resource
      client.put path, params: params, auth: true do |response|
        if block_given?
          yield response
        else
          fail response.body unless response.success?

          response_to_mash response
        end
      end
    end

    def get(resource, params = {}, &ablock)
      path = user_path resource, params
      client.get path, auth: true do |response|
        if block_given?
          yield response
        else
          fail response.body unless response.success?

          response_to_mash response
        end
      end
    end

    def user_path(action, params = {})
      resource = params.delete(:resource) || 'user'
      path = "/api/v1/#{resource}/#{action}"
      # TODO: find a better way to handle multiple parameters, dig into HTTParty
      path += '?' if params.size.positive?
      params.each do |key, value|
        path += "#{key}=#{value}&"
      end
      path
    end

    def response_handler(response, ablock)
      if ablock
        ablock.yield response
      else
        fail response.body unless response.success?

        response_to_mash response
      end
    end

    def response_to_mash(response)
      if response.parsed_response.is_a? Array
        response.to_a.map { |s| Bitmex::Mash.new s }
      else
        Bitmex::Mash.new response
      end
    end
  end
end