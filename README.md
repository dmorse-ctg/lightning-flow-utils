This repo contains a collection of reusable flow utils that can be used to enhance Lightning Flow from Salesforce. 

# Invocable Apex
Can be added to both to both screen flows and auto-launched flows as actions, and execute entirely in the Salesforce cloud.

## 1. Convert Records to CSV

### Summary
This action takes a list of sObject records, generates a CSV report and uploads to your Salesforce files. 

### Inputs
Required:
- sObject Collection
- Document Title

_Optional:_
- Document Visibility
- Document Sharing
- Linked record ids for document
- Custom CSV columns names (sObject primary + related fields)
- Execute asynchronously
- Supports generating a platform event of type 'CSV_Document__e'. The platform event does not come packaged with this, you will need to create it manually for now.

### Outputs
If the action is executed asynchronously (indicated via parameter), then the job id(s) for the execution are returned imediately and document information is published via platform event. Otherwise CSV document information is returned immediately. 

Go to [x: TODO] to read more or to download and install the package. 

