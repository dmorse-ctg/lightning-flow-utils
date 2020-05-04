This repo contains a collection of reusable flow utils that can be used to enhance Lightning Flow from Salesforce. 

# Invocable Apex
Can be added to both to both screen flows and auto-launched flows as actions, and execute entirely in the Salesforce cloud.

## 1. Convert Records to CSV

### Summary
This action takes a list of sObject records, generates a CSV report and uploads to Salesforce files. By default, the file will associate to the running user. 

### Features
- Specify a string or text collection of record IDs to associate the file to. Each ID will create a single ContentDocumentLink
- Specify the sharing and visibility of each ContentDocumentLink
- Customize the order and fields included in your CSV via text collection or comma-seperated string. This is optional, if left blank, it will export all fields that were in the collection
- Can execute 'asynchronously' if CPU timing is an issue. 
- If run asynchronously, supports generating a platform event of type 'CSV_Document__e'. The platform event does not come packaged with this, you will need to create it manually for now.

### Inputs
Required:
- sObject Collection
- Document Title

_Optional:_
- Document Visibility
- Document Sharing
- Linked record ids for document
- Custom CSV columns names (sObject primary + related fields)
- Asynchronous identifier


### Outputs
If the action is executed asynchronously (indicated via parameter), then the job id(s) for the execution are returned imediately and document information is published via platform event. Otherwise CSV document information is returned immediately. 

Go to [UnofficialSF](https://unofficialsf.com) to read more or to download and install the package. 

