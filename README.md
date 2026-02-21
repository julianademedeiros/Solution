# SOLUTION

## Overview

This solution implements a Lightning Web Component + Apex architecture to manage payment link generation and status tracking directly on the Opportunity record. Key design decisions:

### Separation of concerns:

- PaymentService class handles business logic and orchestration.

- PaymentIntegrationClient class handles all callouts to the payment provider, including POST for generating links and GET for status.

- LWC paymentLinkPanel handles the user interface, including button states, toast messages, and reactive updates.

### UI design principles:

- Simple, organized panel with two buttons: Generate Payment Link and Refresh Status.

- Button states are reactive based on the Payment Status (Draft, Sent, Paid).

- Toast notifications provide immediate feedback in UI for success or error.

### Resiliency and error handling:

- Apex methods have layered try/catch blocks to isolate callout errors, DML failures, and unexpected exceptions.

- LWC does not update opportunity fields unless the response is valid.

- getRecordNotifyChange and refreshApex ensure reactive field updates on the UI.

### Scalability considerations:

- Field access in LWC uses getFieldValue from getRecord wire service. Only key fields are imported (Payment_Status__c) to reduce dependencies, but the architecture can easily expand to additional fields.

- Component visibility in the lightning page is declarative so it's easily maintained and it can handle complex business requirements.


## Set Up Instructions (Fresh Sandbox)

### Configure Named Credential

1. Go to Setup → Named Credentials.

2. Create a new Named Credential:

- Label: Payment_API

- Name: Payment_API

- URL: Base URL of your mock API (e.g., https://juliana.free.beeceptor.com)

- Identity Type: Named Principal

- Authentication: If your provider requires API keys, use Headers or Custom Auth Provider.

3. In a real provider scenario, configure authentication headers or OAuth tokens via Named Credential.

4. Ensure your Apex callouts reference the Named Credential (e.g. 'callout:Payment_API')

### Configure API Keys / Metadata

1. Set up mock endpoints (Beeceptor.com in this challenge):

- Create rules:

a. POST /generate -> returns JSON payload { "status": "Sent", "paymentLinkUrl": "...", "referenceId": "..." }

b. GET /status/<referenceId> -> returns JSON payload { "status": "Paid" } 

- Ensure Content-Type: application/json is set in the response headers.

- Write the endpoints with the correct path syntax 

2. Create custom metadata (e.g. Payment API Configuration), custom fields for each API (e.g. Generate Payment path, Status payment path) and records

### Features that MUST be enabled

1. Multiple Currencies must be enabled in the org for this challenge

2. CRUD / FLS for Opportunity fields:

* Payment_Status__c

* Payment_Link_URL__c

* Payment_ReferenceId__c

* Payment_Last_Sync_At__c

3. Create a Permission Set granting access to the classes and assign it to the relevant users 

## Running Tests

* From VS Code terminal, run tests for the relevant test class (e.g. PaymentServiceTest) using the following command:

    sf apex run test --class-names PaymentServiceTest --result-format human --wait 10
    
    OR --- if your CLI is outdated like mine, use the one below:
    
    sfdx force:apex:test:run -n PaymentServiceTest --resultformat human --wait 10
    
* Expected coverage:
    - PaymentIntegrationClient 91%
    - PaymentService 77%
    - Overall code coverage 83%

## Assumptions and Tradeoffs

* Mock API integration: Used Beeceptor to simulate POST/GET endpoints instead of real payment provider

* Reference Id is not dynamic: it’s a fixed value for all records to facilitate testing and demo

* Field imports in LWC: Only Payment_Status__c imported for wire service to limit setup complexity; scalable but not fully generic

* Error handling: Centralized in PaymentService, I wrote some redundant try/catch blocks to make sure everything was captured but it could be streamlined for production

* Page refresh: Used getRecordNotifyChange + refreshApex rather than full page reload; ensures reactive update without complex state management

* I assumed that only users with the dedicated class access Permission Set CAN SEE the component. It's not visible for all users by default since only users with the permission will be able to invoke it 

* Status field values are case-sensitive (Draft, Sent, Paid)

* Closed Won - Validation Rule to mirror the challenge's light business requirements: I used validation rule because it evaluates quickly and it easily references its own object and children related records.  Since the challenge requirement was simple and only had one object layer, I used the validation rule. This is ideal for light business logic, including processes that change often because it has no deployment overhead  (require test classes and 75% code coverage to push into prod). In real orgs however, the opportunity close-won process can be complex by referencing other objects and evaluating multiple fields which would require a more robust validation through Apex Trigger 

* Reactive buttons: though I have included all of the necessary exceptions and error messages, I disabled the buttons in the UI when the fundamental requirements aren't met (e.g. Refresh Status - reference Id cannot be empty). UI control like this helps the user know what they are allowed to do. It gives them visual clarity requiring minimal mental processing. I assumed this would be a valuable function in the UI

* Editable fields in Payment Information section: I allowed the demo user to edit the fields for demo purposes only. In a real org, these fields would be read-only in the Dynamic Form so they can only be updated via the component

## Link to the Dev Org to test implementation
* URL: orgfarm-21ea71eba7-dev-ed.develop.my.salesforce.com
* Username: testuser@orgfarm.devorg

