public with sharing class PaymentIntegrationClient {
    
    // Custom Metadata configuration

	private static Payment_API_Configuration__mdt paymentConfiguration;

	private static Payment_API_Configuration__mdt getPaymentConfiguration() {

    // Initialize the backing variable if it's not already set
   		if (paymentConfiguration == null) {
        paymentConfiguration = Payment_API_Configuration__mdt.getInstance('Default');

        // Missing metadata record exception
        	if (paymentConfiguration == null) {
            throw new CalloutException(
                'Payment API configuration metadata record "Default" was not found.'
            );
        }
    }

    return paymentConfiguration;
}
        
    // Dto to hold payment provider response
    
    public class PaymentResponse {
        public String linkUrl;
        public String referenceId;
        public String status;
    }
    
	// Generates a payment link - Makes POST callout - Named Credential "Payment_API"
    
    public static PaymentResponse generatePaymentLink(
        Id opportunityId,
        Decimal amount,
        String currencyIsoCode,
        String customerEmail
    ) {
        HttpRequest httpRequest = new HttpRequest();
        
        httpRequest.setEndpoint(
            'callout:Payment_API' +
            getPaymentConfiguration().Generate_Payment_Path__c
        );
        
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'opportunityId' => opportunityId,
            'amount' => amount,
            'currency' => currencyIsoCode,
            'customerEmail' => customerEmail
        };
            
        httpRequest.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse httpResponse = http.send(httpRequest);
        
        return handleHttpResponse(httpResponse);
    }
    
    // Fetches payment status - Makes GET callout - Named Credential "Payment_API"
    
    public static PaymentResponse fetchPaymentStatus(
        String referenceId
    ) {
        HttpRequest httpRequest = new HttpRequest();
        
		// String instead of inline to facilitate log/debug of endpoint
    	String endpoint = 'callout:Payment_API' +
                      getPaymentConfiguration().Status_Payment_Path__c +
                      '/' +
                      EncodingUtil.urlEncode(referenceId, 'UTF-8');

    	httpRequest.setEndpoint(endpoint);
        httpRequest.setMethod('GET');
        
        Http http = new Http();
        HttpResponse httpResponse = http.send(httpRequest);
        
        return handleHttpResponse(httpResponse);
    }
    
    // HTTP response handler
    
    private static PaymentResponse handleHttpResponse(
        HttpResponse httpResponse
    ) {
        if (httpResponse == null) {
            throw new CalloutException(
                'No response received from payment provider.'
            );
        }
         if (httpResponse.getStatusCode() != 200) {
            throw new CalloutException(
                'Payment provider returned error. Status: ' +
                httpResponse.getStatus() +
                ' Body: ' +
                httpResponse.getBody()
            );
        }
                return (PaymentResponse)
            JSON.deserialize(
                httpResponse.getBody(),
                PaymentResponse.class
            );
    }
}