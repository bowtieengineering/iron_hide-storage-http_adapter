require 'multi_json'
require 'iron_hide'
require 'iron_hide/storage'
require 'faraday'
require 'securerandom'
require 'jwt'

module IronHide
  class Storage
    class HttpAdapter

      # @option opts [String] :resource *required*
      # @option opts [String] :action *required*
      # @return [Array<Hash>] array of canonical JSON representation of rules
      def where(opts = {})
        # self["#{opts.fetch(:resource)}::#{opts.fetch(:action)}"]
        storage_find(opts.fetch(:resource),opts.fetch(:action))
      end

      private
      # Implements an interface that makes selecting rules look like a Hash:
      # @example
      #   {
      #     'com::test::TestResource::read' => {
      #       ...
      #     }
      #   }
      #  adapter['com::test::TestResource::read']
      #  #=> [Array<Hash>]
      #
      # @param [Symbol] val
      # @return [Array<Hash>] array of canonical JSON representation of rules
      def storage_find(resource,action)
        # payload = MultiJson.dump({resource: resource, action: action})
        payload = "#{resource}::#{action}"
        response = http_rules(payload)
        if !response.empty?
          # MultiJson.load(response)
          response.reduce([]) do |rval, row|
            rval << row["data"]
          end
        else
          []
          # Do Something
        end
      end

      def http_rules(val)
          # "#{server}/#{database}/_design/rules/_view/resource_rules?key=\"#{val}\""
        client = CallMicroservice.new(url: "/api/v1/rules?key=\"#{val}\"", service: server)

        client.get
      end

      def server
        IronHide.configuration.http_host
      end

      # def database
      #   IronHide.configuration.couchdb_database
      # end

    end
    class CallMicroservice
      def initialize(url:, service:)
        @url = url
        @service = service
        @conn = Faraday.new url: "http://" + @service + @url
      end

      def get
        resp = @conn.get do |req|
          req.headers['Authorization'] = token
        end
        MultiJson.load(resp.body)
      end

    private

      def token
        @token ||= JsonWebToken.encode(iss: 'Bowtie Engineering, LLC', sub: @url)
      end
    end
    class JsonWebToken
      class << self
        def encode(payload, exp = 24.hours.from_now)
          payload[:exp] = exp.to_i
          JWT.encode payload, ENV['SECRET_KEY_BASE']
        end

        def decode(token)
          JWT.decode(token, ENV['SECRET_KEY_BASE'])[0]
        rescue
          nil
        end
      end
    end
  end
end

# Add adapter class to IronHide::Storage
IronHide::Storage::ADAPTERS.merge!(http_api: :HttpAdapter)

# Add default configuration variables
IronHide.configuration.add_configuration(http_host: 'authenticatable_app_1')
