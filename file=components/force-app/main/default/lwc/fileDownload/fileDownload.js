import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class FileDownload extends NavigationMixin(LightningElement) {
    @api displayText;
    @api contentDocumentId;
    @api directLink;
    
    handleDownload(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state : {
                recordIds: this.contentDocumentId,
                selectedRecordId:this.contentDocumentId
            }
        });
    }
}