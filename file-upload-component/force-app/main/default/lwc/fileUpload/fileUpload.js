import { LightningElement, api, track } from 'lwc';
import uploadFile from '@salesforce/apex/FilesController.uploadFile';

export default class FileUpload extends LightningElement {
    @api displayText;
    @api relatedRecordIds;
    @api linkedRecordString;
    @api linkedRecordCollection;
    @api fileShareType;
    @api fileVisibility;

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
        console.log('files: ' + JSON.stringify(this.filesUploaded));
        this.filesUploaded.forEach((file, index) => {
            console.log('File: ' + JSON.stringify(file));
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
                var showToast = index == this.filesUploaded.length - 1
                this.uploadFile(file.name, contents, showToast);
            });
            fileReader.readAsDataURL(file);
        });
    }

    // Calling apex class to insert the file
    uploadFile(name, contents, showToast) {
        uploadFile({ fileName: name, fileExtension: '.csv', fileContents: contents, documentShareType: this.fileShareType, documentVisibility: this.fileVisibility, linkedREcordIds: this.linkedRecordCollection})
        .then(result => {
            window.console.log('result ====> ' +result);

            // Showing Success message after file insert
            if (showToast) {
                this.resetState();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: name + ' - Uploaded Successfully!',
                        variant: 'success',
                    }),
                );
            }
        })
        .catch(error => {
            // Showing errors if any while inserting the files
            console.log(error);
            this.resetState();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Uploading File',
                    message: error.message,
                    variant: 'error',
                }),
            );
        });
    }

    resetState() {
        this.showSpinner = false;
        this.uploadedFiles = [];
        this.disableUpload = true;
    }
}