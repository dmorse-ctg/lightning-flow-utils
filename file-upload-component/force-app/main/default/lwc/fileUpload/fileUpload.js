import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/FilesController.uploadFile';

export default class FileUpload extends LightningElement {
    // Inputs
    @api displayText;
    @api linkedRecordString;
    @api linkedRecordCollection;
    @api fileShareType;
    @api fileVisibility;
    @api acceptMultiple = false;

    // Outputs 
    @api contentDocumentId;
    @api contentVersionId;
    @api contentDocumentLinkIds;
    @api contentDocumentLinks;

    MAX_FILE_SIZE = 1500000;

    @track filesUploaded = [];
    @track showSpinner = false;
    @track showError = false;
    @track errorText = "";
    @track disableUpload;

    connectedCallback() {
        this.disableUpload = true;
    }

    handleFilesChange(event) {
        if (event.target.files.length > 0) {
            this.filesUploaded = event.target.files;
            this.disableUpload = false;
        }
    }

    handleSave() {
        if (this.filesUploaded.length > 0) {
            this.uploadHelper();
        } else {
            this.showError = true;
            this.errorText = 'Please select file to upload';
        }
    }

    uploadHelper() {
        this.showSpinner = true;

        var file = this.filesUploaded[0];
        if (file.size > this.MAX_FILE_SIZE) {
            console.log('File Size is to long');
            return ;
        }
        console.log('Uploaded file: ' + file.name);
        // create a FileReader object 
        var fileReader = new FileReader();
        // set onload function of FileReader object  
       fileReader.onloadend = (() => {
            var fileContents = fileReader.result;
            let base64 = 'base64,';
            var content = fileContents.indexOf(base64) + base64.length;
            fileContents = fileContents.substring(content);
            
            // call the uploadProcess method 
            // var showToast = i == this.filesUploaded.length - 1

            this.uploadFile(file.name, fileContents, true);
        });
        fileReader.readAsDataURL(file);
        // this.filesUploaded.forEach((file, index) => {

        // });
    }

    // Calling apex class to insert the file
    uploadFile(name, contents, showToast) {
        uploadFile({ fileName: name, versionData: contents, documentShareType: this.fileShareType, documentVisibility: this.fileVisibility, linkedRecordIds: this.linkedRecordCollection})
        .then(result => {
            window.console.log('result ====> ' +result);

            this.contentDocumentId = result.ContentDocumentId;
            this.contentVersionId = result.ContentVersionId;
            this.contentDocumentLinkIds = result.ContentDocumentLinks.map(link => {
                return link.Id;
            });
            this.contentDocumentLinks = result.ContentDocumentLinks;

            // Showing Success message after file insert
            if (showToast) {
                // var fileNames = this.filesUploaded.reduce((fullText, file) => fullText += file.name + ', ');
                // fileNames = fileNames.substring(0, str.length - 1);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: name + ' - Uploaded Successfully',
                        variant: 'success',
                    }),
                );
                this.resetState();
            }
        })
        .catch(error => {
            // Showing errors if any while inserting the files
            console.log('Error: ' + error);
            this.resetState();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error uploading file. Please try again.',
                    message: error.message,
                    variant: 'error',
                }),
            );
        });
    }

    resetState() {
        this.showSpinner = false;
        this.filesUploaded = [];
        this.disableUpload = true;
    }
}