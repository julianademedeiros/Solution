import { LightningElement, api, wire, track } from 'lwc';
import generatePaymentLink from '@salesforce/apex/PaymentService.generatePaymentLink';
import refreshPaymentStatus from '@salesforce/apex/PaymentService.refreshPaymentStatus';
import paymentStatus from '@salesforce/schema/Opportunity.Payment_Status__c';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

export default class PaymentLinkPanel extends LightningElement {
    @api recordId;
    
    @track opportunityRecord;
    @track paymentLinkUrl;
    @track referenceId;
    @track status;
    @track lastSyncAt;
    @track errorMessage;
    @track isGenerating = false;

    @wire(getRecord, { recordId: '$recordId', fields: [paymentStatus]})
    wiredOpportunity({ error, data }) {
        this.opportunityRecord = data;
    }

    get opportunityStatus(){
        return this.opportunityRecord
        ? getFieldValue(this.opportunityRecord, paymentStatus)
        : null;
    }

    get isGenerateDisabled() {
        return (this.opportunityStatus === 'Sent' || this.opportunityStatus === 'Paid');
    }

    handleGenerateLink() {
        this.clearError();
        this.isGenerating = true;

        generatePaymentLink({ opportunityId: this.recordId })
            .then(result => {
                if (result.errorMessage) {
                    this.errorMessage = result.errorMessage;

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: this.errorMessage,
                            variant: 'error'
                        })
                    );
                } else {
                    this.paymentLinkUrl = result.paymentLinkUrl;
                    this.referenceId = result.referenceId;
                    this.status = result.status;
                    this.lastSyncAt = result.lastSyncAt;

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Payment link generated and sent to customer.',
                            variant: 'success'
                        })
                    );

                    getRecordNotifyChange([{ recordId: this.recordId}]);
                    refreshApex(this.opportunityRecord);
                }
            })
            .catch(error => {
                this.errorMessage =
                    error.body ? error.body.message : error.message;

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: this.errorMessage,
                            variant: 'error'
                        })
                    );
            })
            .finally(() => {
                this.isGenerating = false;
            });
    }

    handleRefreshStatus() {
        this.clearError();

        refreshPaymentStatus({ opportunityId: this.recordId })
            .then(result => {
                if (result.errorMessage) {
                    this.errorMessage = result.errorMessage;
                } else {
                    this.paymentLinkUrl = result.paymentLinkUrl;
                    this.referenceId = result.referenceId;
                    this.status = result.status;
                    this.lastSyncAt = result.lastSyncAt;

                    refreshApex(this.opportunityRecord);
                }
            })
            .catch(error => {
                this.errorMessage =
                    error.body ? error.body.message : error.message;
            });
    }

    clearError() {
        this.errorMessage = null;
    }
}