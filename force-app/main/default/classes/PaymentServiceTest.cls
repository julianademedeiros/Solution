@IsTest
private class PaymentServiceTest {

   	/* TEST DATA FACTORY */
    
    private static Opportunity createTestOpportunity(Boolean includePrimaryContact, Boolean includeEmail) {

        // Create Account
        Account accountRecord = new Account(Name = 'Test Account');
        insert accountRecord;

        // Create Opportunity with required fields
        Opportunity opportunityRecord = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Amount = 250,
            CurrencyIsoCode = 'USD',
            AccountId = accountRecord.Id
        );
        insert opportunityRecord;

        // Optionally create primary contact
        if (includePrimaryContact) {

            Contact contactRecord = new Contact(
                LastName = 'Test Contact',
                Email = includeEmail ? 'test@example.com' : null,
                AccountId = accountRecord.Id
            );
            insert contactRecord;

            OpportunityContactRole contactRole = new OpportunityContactRole(
                OpportunityId = opportunityRecord.Id,
                ContactId = contactRecord.Id,
                IsPrimary = true,
                Role = 'Decision Maker'
            );
            insert contactRole;
        }

        return opportunityRecord;
    }


	/* MOCK: SUCCESSFUL PAYMENT LINK GENERATION */
    
	private class SuccessfulPaymentLinkMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest request) {

        // Validate HTTP method is POST
        System.assertEquals('POST', request.getMethod(), 'Expected HTTP method POST');

        // Validate endpoint uses the named credential
        System.assert(request.getEndpoint().startsWith('callout:Payment_API'), 
                      'Endpoint should start with callout:Payment_API');

        // Build mock response
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{' +
            '"linkUrl":"https://mocki.payment/link",' +
            '"referenceId":"123456",' +
            '"status":"sent"' +
        '}');

        return response;
    }
}


    /* MOCK: FAILED PAYMENT LINK GENERATION */
    
    private class FailedPaymentLinkMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('Internal Server Error');
            return response;
        }
    }


	/* MOCK: SUCCESSFUL STATUS SYNCHRONIZATION */
    
	private class SuccessfulStatusSynchronizationMock implements HttpCalloutMock {

   		public HttpResponse respond(HttpRequest request) {

        	System.assertEquals('GET', request.getMethod(), 'Expected HTTP method GET');

            // Ensure endpoint uses the named credential and contains the referenceId 
        	System.assert(request.getEndpoint().startsWith('callout:Payment_API'), 
                      'Endpoint should start with callout:Payment_API');
        	System.assert(request.getEndpoint().contains(EncodingUtil.urlEncode('123456', 'UTF-8')),
                      'Endpoint should include the referenceId as path parameter');

        	HttpResponse response = new HttpResponse();
        	response.setStatusCode(200);
        	response.setBody('{' +
            	'"linkUrl":"https://mocki.payment/link",' +
            	'"referenceId":"123456",' +
            	'"status":"Paid"' +
        	'}');

        	return response;
    	}
	}


    /* MOCK: FAILED STATUS SYNCHRONIZATION */

    private class FailedStatusSynchronizationMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('Internal Server Error');
            return response;
        }
    }


    /* TEST: SUCCESSFUL PAYMENT LINK GENERATION */

    @IsTest
    static void testSuccessfulPaymentLinkGenerationUpdatesFieldsCorrectly() {

        Opportunity opportunityRecord =
            createTestOpportunity(true, true);

        Test.setMock(HttpCalloutMock.class, new SuccessfulPaymentLinkMock());

        Test.startTest();
        PaymentService.PaymentResult result =
            PaymentService.generatePaymentLink(opportunityRecord.Id);
        Test.stopTest();

        Opportunity updatedOpportunity = [
            SELECT Payment_Link_URL__c,
                   Payment_ReferenceId__c,
                   Payment_Status__c,
                   Payment_Last_Sync_At__c
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        System.assertEquals('https://mocki.payment/link', updatedOpportunity.Payment_Link_URL__c);
        System.assertEquals('123456', updatedOpportunity.Payment_ReferenceId__c);
        System.assertEquals('Sent', updatedOpportunity.Payment_Status__c);
        System.assertNotEquals(null, updatedOpportunity.Payment_Last_Sync_At__c);

        System.assertEquals(null, result.errorMessage);
    }


    /* TEST: FAILED GENERATION DOES NOT OVERWRITE EXISTING VALUES */
    
    @IsTest
    static void testFailedPaymentLinkGenerationPreservesExistingValues() {

        Opportunity opportunityRecord =
            createTestOpportunity(true, true);

        opportunityRecord.Payment_Link_URL__c = 'https://existing.example';
        opportunityRecord.Payment_ReferenceId__c = 'EXISTING_REFERENCE';
        opportunityRecord.Payment_Status__c = 'Sent';
        update opportunityRecord;

        Test.setMock(HttpCalloutMock.class, new FailedPaymentLinkMock());

        Test.startTest();
        PaymentService.generatePaymentLink(opportunityRecord.Id);
        Test.stopTest();

        Opportunity unchangedOpportunity = [
            SELECT Payment_Link_URL__c,
                   Payment_ReferenceId__c,
                   Payment_Status__c
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        System.assertEquals('https://existing.example', unchangedOpportunity.Payment_Link_URL__c);
        System.assertEquals('EXISTING_REFERENCE', unchangedOpportunity.Payment_ReferenceId__c);
        System.assertEquals('Sent', unchangedOpportunity.Payment_Status__c);
    }


    /* TEST: SUCCESSFUL STATUS SYNCHRONIZATION */
    
    @IsTest
    static void testSuccessfulStatusSynchronizationUpdatesStatus() {

        Opportunity opportunityRecord =
            createTestOpportunity(true, true);

        opportunityRecord.Payment_ReferenceId__c = '123456';
        opportunityRecord.Payment_Status__c = 'Sent';
        update opportunityRecord;

        Test.setMock(HttpCalloutMock.class, new SuccessfulStatusSynchronizationMock());

        Test.startTest();
        PaymentService.refreshPaymentStatus(opportunityRecord.Id);
        Test.stopTest();

        Opportunity updatedOpportunity = [
            SELECT Payment_Status__c,
                   Payment_Last_Sync_At__c
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        System.assertEquals('Paid', updatedOpportunity.Payment_Status__c);
        System.assertNotEquals(null, updatedOpportunity.Payment_Last_Sync_At__c);
    }

    
     /* TEST: FAILED STATUS SYNCHRONIZATION PRESERVES VALUE */
    
    @IsTest
    static void testFailedStatusSynchronizationPreservesPreviousValue() {

        Opportunity opportunityRecord =
            createTestOpportunity(true, true);

        opportunityRecord.Payment_ReferenceId__c = '123456';
        opportunityRecord.Payment_Status__c = 'Sent';
        update opportunityRecord;

        Test.setMock(HttpCalloutMock.class, new FailedStatusSynchronizationMock());

        Test.startTest();
        PaymentService.refreshPaymentStatus(opportunityRecord.Id);
        Test.stopTest();

        Opportunity unchangedOpportunity = [
            SELECT Payment_Status__c
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        System.assertEquals('Sent', unchangedOpportunity.Payment_Status__c);
    }

    /* TEST: NO PRIMARY CONTACT ERROR MESSAGE */
    
    @IsTest
	static void testGeneratePaymentLinkNoPrimaryContact() {
        
    Opportunity opportunityRecord = PaymentServiceTest.createTestOpportunity(false, true);

    PaymentService.PaymentResult result = PaymentService.generatePaymentLink(opportunityRecord.Id);

    System.assertNotEquals(null, result.errorMessage, 'Error message should be populated when no primary contact exists.');
    System.assert(result.errorMessage.contains('no primary contact'), 'Error message should mention missing primary contact.');
}
}