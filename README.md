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
- Record (sObject) Collection
  - Description: The collection you want a CSV of 
  - API Name: `recordCollection`
  - Type: Text
- Document Title
  - Description: The title of the File when generated 
  - API Name: `documentTitle`
  - Type: Text

_Optional:_
- Document Visibility
  - Description: Specifies whether the document is available to all users, internal users, or shared users. Available values: "AllUsers", "InternalUsers", "SharedUsers"; Default value: "AllUsers" 
  - API Name: `documentVisibility`
  - Type: Text
- Document Sharing
  - Description: Sharing permissions for the file. Available values: "V" (viewer), "C" (collaborator), "I" (inferred); Default value: "V"
  - API Name: `documentShareType`
  - Type: Text
- Linked record ids for document
  - Description: List of record Id’s to link the generated document to. If left blank, will only relate to the running user. Supports comma separated text or Collection from Flow
  - API Name(s): `linkedRecordIds`, `linkedRecordIdsString`
  - Type(s): Collection, Text (respectively)
- Custom CSV column names
  - Description: List of record fields names to print as columns in CSV. If null, all populated fields on the records will be displayed. _IMPORTANT_: If you want to include related fields from an SOQL query (Custom_Object__r.Custom__c) this parameter is required. If you used aliasing on for an aggregate query, alias names can be provided rather than the API names. 
  - API Name(s): `fieldsCollection`, `fieldsString`
  - Type(s): Collection, Text (respectively)

- Asynchronous identifier
  - Description: If provided, the action will execute asynchronously, and generated document information will be posted to a platform event: `CSV_Document__e`. Use this identifier to listen for the platform event in a 'Wait' element in Flow or use Summer 20's 'Invoke Flow from a Platform Event'. 
  - API Name: `executeAsyncIdentifier`
  - Type: Text 

### Outputs
If the action is executed asynchronously (indicated via parameter), then the job id(s) for the execution are returned imediately and document information is published via platform event. Otherwise CSV document information is returned immediately. 

Go to [UnofficialSF](https://unofficialsf.com) to read more or to download and install the package. 

