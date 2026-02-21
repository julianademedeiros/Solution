public with sharing class PaymentService {

    // DTO to return results to LWC

    public class PaymentResult {
        @AuraEnabled public String paymentLinkUrl;
        @AuraEnabled public String referenceId;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime lastSyncAt;
        @AuraEnabled public String errorMessage;
    }

    // Generate a payment link in the Opportunity

    @AuraEnabled
    public static PaymentResult generatePaymentLink(Id opportunityId) {
        PaymentResult result = new PaymentResult();


        try {
        
            Opportunity opp = [
                SELECT Id, Amount, CurrencyIsoCode,
                       (SELECT Contact.Email, IsPrimary 
                        FROM OpportunityContactRoles 
                        WHERE IsPrimary = TRUE LIMIT 1)
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            // Check if primary contact exists in Opportunity Contact Role, is it still associated
            if (opp.OpportunityContactRoles.isEmpty() || opp.OpportunityContactRoles[0].Contact == null) {
                result.errorMessage = 'This opportunity has no primary contact.';
                return result;
            }

            String customerEmail = opp.OpportunityContactRoles[0].Contact.Email;
            if(String.isBlank(customerEmail)){
               result.errorMessage = 'The primary contact in this opportunity has no email.';
               return result;
            }

            // Call PaymentIntegrationClient Class - Generate link
            PaymentIntegrationClient.PaymentResponse response = PaymentIntegrationClient.generatePaymentLink(
                opp.Id,
                opp.Amount,
                opp.CurrencyIsoCode,
                customerEmail
            );

            // Update Opportunity fields after successful callout
            try { 
                opp.Payment_Link_URL__c = response.linkUrl;
                opp.Payment_ReferenceId__c = response.referenceId;
                opp.Payment_Status__c = response.status;
                opp.Payment_Last_Sync_At__c = System.now();

                update opp;

            } catch (DmlException de) {
                result.errorMessage = 'Failed to update Opportunity ' + opportunityId + '. Contact your administrator with the following message: ' + de.getMessage();
                System.debug('PaymentService.generatePaymentLink DML error for Opportunity ' 
                             + opportunityId + ': ' + de);
                return result; // If update fails, the process ends here and doesn't update LWC
            }

            // Populate result DTO for LWC
            result.paymentLinkUrl = String.isBlank(opp.Payment_Link_URL__c) ? null : opp.Payment_Link_URL__c;
            result.referenceId = opp.Payment_ReferenceId__c;
            result.status = opp.Payment_Status__c;
            result.lastSyncAt = opp.Payment_Last_Sync_At__c;

        } catch (CalloutException ce) {
            result.errorMessage = 'Payment provider call failed for Opportunity ' + opportunityId + '. Contact your administrator with the following message: ' + ce.getMessage();
            System.debug('PaymentService.generatePaymentLink callout error for Opportunity ' 
                         + opportunityId + ': ' + ce);

        } catch (Exception e) {
            result.errorMessage = 'Unexpected error during payment link generation for Opportunity ' + opportunityId + '. Contact your administrator with the following message: ' + e.getMessage();
            System.debug('PaymentService.generatePaymentLink unexpected error for Opportunity ' 
                         + opportunityId + ': ' + e);
        }

        return result;
    }

    // Refresh payment status in Opportunity

    @AuraEnabled
    public static PaymentResult refreshPaymentStatus(Id opportunityId) {
        PaymentResult result = new PaymentResult();

        try {
            
            Opportunity opp = [
                SELECT Id, Payment_ReferenceId__c,
                       Payment_Link_URL__c, Payment_Status__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            if (String.isBlank(opp.Payment_ReferenceId__c)) {
                result.errorMessage = 'No payment reference Id found for Opportunity ' + opportunityId + '.';
                return result;
            }

            // Call PaymentIntegrationClient - Fetch status
            PaymentIntegrationClient.PaymentResponse response = PaymentIntegrationClient.fetchPaymentStatus(
                opp.Payment_ReferenceId__c
            );

            // Update Opportunity fields after successful callout
            try {
                opp.Payment_Status__c = response.status;
                opp.Payment_Last_Sync_At__c = System.now();

            update opp;

            } catch (DmlException de) {
                result.errorMessage = 'Failed to update Opportunity payment status ' + opportunityId + '. Contact your administrator with the following message: ' + de.getMessage();
                System.debug('PaymentService.refreshPaymentStatus DML error for Opportunity ' 
                             + opportunityId + ': ' + de);
                return result;                
            }

            // Populate result DTO for LWC
            result.paymentLinkUrl = opp.Payment_Link_URL__c;
            result.referenceId = opp.Payment_ReferenceId__c;
            result.status = response.status;
            result.lastSyncAt = opp.Payment_Last_Sync_At__c;

        } catch (CalloutException ce) {
            result.errorMessage = 'Payment provider call failed for Opportunity ' + opportunityId + '. Contact your administrator with the following message: ' + ce.getMessage();
            System.debug('PaymentService.refreshPaymentStatus callout error for Opportunity ' 
                         + opportunityId + ': ' + ce);
        } catch (Exception e) {
            result.errorMessage = 'Unexpected error during payment status refresh for Opportunity ' + opportunityId + '. Contact your administrator with the following message: ' + e.getMessage();
            System.debug('PaymentService.refreshPaymentStatus unexpected error for Opportunity ' 
                         + opportunityId + ': ' + e);
        }

        return result;
    }
}