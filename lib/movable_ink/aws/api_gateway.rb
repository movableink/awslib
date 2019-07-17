require 'aws-sdk'
require 'aws-sigv4'
require 'httparty'

module MovableInk
  class AWS
    module ApiGateway
      def post_signed_gateway_request(gateway_url:, region:, body:)
        credentials = Aws::CredentialProviderChain.new.resolve.credentials

        signer = Aws::Sigv4::Signer.new({
          service: 'execute-api',
          region: region,
          credentials: credentials
        })

        signature = signer.sign_request({
          http_method: 'POST',
          url: gateway_url,
          body: body,
        })

        HTTParty.post(gateway_url, {
          headers: signature.headers,
          body: body,
        })
      end
    end
  end
end
