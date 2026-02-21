import { LightningElement, api, track } from 'lwc';
import generatePaymentLink from '@salesforce/apex/PaymentService.generatePaymentLink';
import refreshPaymentStatus from '@salesforce/apex/PaymentService.refreshPaymentStatus';

export default class PaymentLinkPanel extends LightningElement {
    @api recordId;
    
    @track paymentLinkUrl;
    @track referenceId;
    @track status;
    @track lastSyncAt;
    @track errorMessage;

    @track isGenerating = false;

    get isGenerateDisabled() {
        return this.status === 'sent' || this.isGenerating;
    }

    handleGenerateLink() {
        this.clearError();
        this.isGenerating = true;

        generatePaymentLink({ opportunityId: this.recordId })
            .then(result => {
                if (result.errorMessage) {
                    this.errorMessage = result.errorMessage;
                } else {
                    this.paymentLinkUrl = result.paymentLinkUrl;
                    this.referenceId = result.referenceId;
                    this.status = result.status;
                    this.lastSyncAt = result.lastSyncAt;
                }
            })
            .catch(error => {
                this.errorMessage =
                    error.body ? error.body.message : error.message;
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