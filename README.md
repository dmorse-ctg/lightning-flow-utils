This repo contains a collection of reusable flow utils that can be used to enhance Lightning Flow from Salesforce. 

# Invocable Apex
Can be added to both to both screen flows and auto-launched flows as actions, and execute entirely in the Salesforce cloud.

## 1. Convert Records to CSV

### Summary
This action takes a list of sObject records, generates a CSV report and uploads to your Salesforce files. 

### Inputs
Required:
- sObject List
- Document Title
- Document Visibility
- Document Sharing

_Optional:_
- Linked record ids for document
- Custom CSV columns names (sObject primary + releated fields)
- Execute asynchronously

### Outputs
If the action is executed asynchronously (indicated via parameter), then the job id(s) for the execution are returned imediately and document information is published via platform event. Otherwise CSV document information is returned immediately. 

Go to [x: TODO] to read more or to download and install the package. 

