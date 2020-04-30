global without sharing class ConvertRecordsToCSV {

    class GenerateCSVException extends Exception {}

    // Max number of iterations that can occur before we hit heap limits running synchronously
    private static Integer SYNC_ITERATION_LIMIT = 200000;

    public enum CSVParseType {
        HEADERS_ONLY,
        ROWS_ONLY,
        ALL
    }

    global class Inputs {
        @InvocableVariable(description='List of sObject records to print in report' required=true)
        global List<SObject> sObjectCollection;
    
        @InvocableVariable(description='Title of the report' required=true)
        global String documentTitle;

        @InvocableVariable(description='Sharing permissions for the file. Valid values: "V" (viewer), "C" (collaborator), "I" (inferred); Default value: "V"')
        global String documentShareType;

        @InvocableVariable(description='Specifies whether the document is available to all users, internal users, or shared users. Valid values: "AllUsers", "InternalUsers", "SharedUsers"; Default value: "AllUsers"')
        global String documentVisibility;
    
        @InvocableVariable(description='Optional list of recordIds to link generated document to')
        global List<String> linkedRecordIds;

        @InvocableVariable(description='Optional comma-separated string of recordIds to link generated document to')
        global String linkedRecordIdsString;

        @InvocableVariable(description='Optional: Explicit collection of fields to report on CSV. If null, all populated fields on the sObject will be displayed. NOTE: If you need to print related fields this parameter is required.')
        global List<String> fieldsCollection;

        @InvocableVariable(description='Optional: Explicit comma-separated string of fields to report on CSV. If null, all populated fields on the sObject will be displayed. NOTE: If you need to print related fields this parameter is required.')
        global String fieldsString;

        @InvocableVariable(description='If true the action will execute asynchrounously and return values will be posted to a platform event: CSV_Document__e')
        global Boolean executeAsynchronously;
    }

    global class Outputs {
        @InvocableVariable(description='Id for ContentDocument generated')
        global String contentDocumentId;
    
        @InvocableVariable(description='Id for ContentVersion generated')
        global String contentVersionId;
    
        @InvocableVariable(description='If you provided linked record Ids, this will returned the related ContentDocumentLinks for each')
        global List<ContentDocumentLink> contentDocumentLinks;

        @InvocableVariable(description='Id of the asynchronous job queued (AsyncApexJob). If the action was executed asynchronously all other return values will be null. Use this to query for status of the job.')
        global List<ID> asyncJobIds;
    }

    @InvocableMethod(label='Generate sObject CSV Report' description='Generates a CSV of all sObject field values for the list provided. Generates a document and optionally links it to the related object provided.' category='Reporting')
    public static List<ConvertRecordsToCSV.Outputs> generateCSV(List<ConvertRecordsToCSV.Inputs> inputVariables) {
        if (inputVariables.size() == 0) {
            throw new GenerateCSVException('No input variables provided.');
        }

        List<ConvertRecordsToCSV.Outputs> outputs = new List<ConvertRecordsToCSV.Outputs>{};
        for (Inputs input: inputVariables) {
            List<String> fieldsList = input.fieldsCollection;
            if (input.fieldsString != null) {
                fieldsList = input.fieldsString.split(',');
                if (fieldsList.size() == 0) {
                    throw new GenerateCSVException('Invalid list of primary fields provided. The string is not comma separated.');
                }
            }
    
            List<String> linkedRecordIds = input.linkedRecordIds;
            if (input.linkedRecordIdsString != null) {
                linkedRecordIds = input.linkedRecordIdsString.split(',');
                if (linkedRecordIds.size() == 0) {
                    throw new GenerateCSVException('Invalid list of linked record ids provided. The string is not comma separated.');
                }
            }
    
            Boolean executeAsync = input.executeAsynchronously == null ? false: input.executeAsynchronously;
            if (!executeAsync && fieldsList != null && fieldsList.size()*input.sObjectCollection.size() > SYNC_ITERATION_LIMIT) {
                throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
            }
    
            if (!executeAsync) {
                String fullCSV = generateCSVContent(input.sObjectCollection, fieldsList, CSVParseType.ALL, executeAsync);
                ConvertRecordsToCSV.Outputs returnVal = generateDocument(input.linkedRecordIds, input.documentTitle, input.documentShareType, input.documentVisibility, fullCSV);
                return new List<ConvertRecordsToCSV.Outputs>{returnVal};
            }
            List<SObject> splitList = new List<SObject>{};
            while (splitList.size() < input.sObjectCollection.size()) {
                splitList.add(input.sObjectCollection.remove(0));
            }
            String headersCSV = generateCSVContent(input.sObjectCollection, fieldsList, CSVParseType.HEADERS_ONLY, executeAsync);
            ConvertRecordsToCSV.Outputs initialDoc = generateDocument(input.linkedRecordIds, input.documentTitle, input.documentShareType, input.documentVisibility, headersCSV);
               ID jobId = System.enqueueJob(new ConvertRecordsToCSVQueueable(input.sObjectCollection, fieldsList, initialDoc.contentDocumentLinks, initialDoc.contentVersionId, initialDoc.contentDocumentId));
               ID jobId2 = System.enqueueJob(new ConvertRecordsToCSVQueueable(splitList, fieldsList, initialDoc.contentDocumentLinks, initialDoc.contentVersionId, initialDoc.contentDocumentId));
            Outputs returnVal = new Outputs();
            returnVal.asyncJobIds = new List<ID>{jobId, jobId2};
    
            outputs.add(returnVal);
        }
        return outputs;
    }

    public static String generateCSVContent(List<SObject> objectList, List<String> fieldList, CSVParseType parseType, Boolean executingAsync) {
        if (objectList[0].getSObjectType().getDescribe().getName() == 'AggregateResult') { 
            // Handle AggregateResult type
            return generateAggregateResultCSV(objectList, fieldList, parseType, executingAsync);
        }
        // Handle record type sObject
        return ConvertRecordsToCSV(objectList, fieldList, parseType, executingAsync);
    }

    // Generate headers and rows for queries that return AggregateResult type sObjects
    @TestVisible
    private static String generateAggregateResultCSV(List<SObject> objectList, List<String> fieldList, CSVParseType parseType, Boolean executingAsync) {
        Set<String> columnHeaders = new Set<String>{};
        List<String> columnRows = new List<String>{};

        String columnHeadersCSV = '';
        String columnRowsCSV = '';

        // If primary fields were provided, set them to the column values
        if (fieldList != null) {
            columnHeaders = new Set<String>(fieldList);
            if (parseType == CSVParseType.HEADERS_ONLY || parseType == CSVParseType.ALL) {
                columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
            }
            
            if (parseType == CSVParseType.ROWS_ONLY || parseType == CSVParseType.ALL) {
                String columnRow = '';
                for (AggregateResult result: (List<AggregateResult>)objectList) {
                    for (String header: columnHeaders) {
                        Object fieldValue = result.get(header);
                        if (fieldValue != null) {
                            columnRow += String.valueOf(fieldValue).replaceAll('\r\n|\n|\r',' ').replace(',', '');
                        } else {
                            columnRow += 'null';
                        }
                        columnRow += ',';
                    }
                }
                columnRowsCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
            }
        } else {
            List<Map<String, Object>> soFieldList = new List<Map<String, Object>>{};
            // Else, get union of all populated field names
            for (AggregateResult result: (List<AggregateResult>)objectList) {
                soFieldList.add((Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(result)));
            }

            for (Map<String, Object> data: soFieldList) {
                columnHeaders.addAll(data.keySet());
            }

            // Check limits
            if (!executingAsync && parseType != CSVParseType.HEADERS_ONLY && columnHeaders.size()*objectList.size() > SYNC_ITERATION_LIMIT) {
                throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
            }
            
            if (parseType == CSVParseType.HEADERS_ONLY || parseType == CSVParseType.ALL) {
                columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
            }
            
            if (parseType == CSVParseType.ROWS_ONLY || parseType == CSVParseType.ALL) {
                // 2. Set values in rows
                for (Map<String, Object> data: soFieldList) {
                    String columnRow = '';
                    for (String header: columnHeaders) {
                        if (data.get(header) != null) {
                            columnRow += String.valueOf(data.get(header)).replaceAll('\r\n|\n|\r',' ').replace(',', '');
                            // columnRow += getDisplayTextForFieldType(fieldValue, fieldType);
                        } else {
                            columnRow += 'null';
                        }
                        columnRow += ',';
                    }
                    columnRows.add(columnRow);
                }
                columnRowsCSV = String.join(columnRows, '\n');
            }
        }
        return columnHeadersCSV + columnRowsCSV;
    }

    // Generate headers and rows for queries that return record type sObjects
    @TestVisible
    private static String ConvertRecordsToCSV(List<SObject> objectList, List<String> fieldList, CSVParseType parseType, Boolean executingAsync) {
        Set<String> columnHeaders = new Set<String>{};
        List<String> columnRows = new List<String>{};

        String columnHeadersCSV = '';
        String columnRowsCSV = '';

        // If primary fields were provided, set them to the column values
        if (fieldList != null) {
            columnHeaders = new Set<String>(fieldList);
            if (parseType == CSVParseType.HEADERS_ONLY || parseType == CSVParseType.ALL) {
            	columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
            }
        }

        for (SObject so: objectList) {
            Map<String,Schema.SObjectField> allFields = so.getSObjectType().getDescribe().fields.getMap();
            Map<String, Object> populatedFields = so.getPopulatedFieldsAsMap();

            if (fieldList == null) {
                // If no primary fields are provided, add all populated fields, removing any that aren't in the all fields list
                Set<String> populatedFieldNames = new Set<String>{};
                Set<String> allFieldsKeySet = allFields.keySet();
                for (String field: populatedFields.keySet()) {
                    if (allFieldsKeySet.contains(field.toLowerCase())) { // retainAll on the set does not work because causes do not match
                        populatedFieldNames.add(field);
                    }
                }
                columnHeaders.addAll(populatedFieldNames);

                // Check limits
                if (!executingAsync && parseType != CSVParseType.HEADERS_ONLY && columnHeaders.size()*objectList.size() > SYNC_ITERATION_LIMIT) {
                    throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
                }
                
                if (parseType == CSVParseType.HEADERS_ONLY || parseType == CSVParseType.ALL) {
                	columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
                }
            }

            if (parseType == CSVParseType.ROWS_ONLY || parseType == CSVParseType.ALL) {
                String columnRow = '';
                for (String header: columnHeaders) {
                    if (populatedFields.get(header) != null) {
                        Schema.SObjectField field = allFields.get(header);
                        if (field != null && (field.getDescribe().getType() == Schema.DisplayType.ADDRESS || field.getDescribe().getType() == Schema.DisplayType.LOCATION)) {
                            // handle compound fields like address and location
                            columnRow += JSON.serialize(populatedFields.get(header)).escapeCsv();
                        } else {
                            columnRow += String.valueOf(populatedFields.get(header)).replaceAll('\r\n|\n|\r',' ').escapeCsv();
                        }
                    } else if (header.contains('.')) { // 3. Handle Related Fields
                        // pull related fields and add data
                        List<String> fieldComponents = header.split('\\.');
                        SObject traverse = so;
                        for (Integer i = 0; i < fieldComponents.size(); i++) {
                            String comp = fieldComponents[i];
                            System.debug('Searching component: ' + comp);
    
                            if (i < fieldComponents.size() - 1) {
                                traverse = traverse.getSObject(comp);
                                System.debug('Related object: ' + traverse);
                            } else if (traverse != null) {
                                // get field value for the last field component
                                System.debug('Getting related field');
                                Object fieldValue = traverse.get(comp);
                                if (fieldValue == null) {
                                    throw new GenerateCSVException('Invalid related list provided. Could not find field ' + comp + ' on ' + traverse);
                                }
                                Schema.DisplayType fieldType = traverse.getSObjectType().getDescribe().fields.getMap().get(comp).getDescribe().getType();
                                columnRow += getDisplayTextForFieldType(fieldValue, fieldType);
                            } else {
                                columnRow += 'null';
                            }
                        }
                    } else {
                        columnRow += 'null';
                    }
                    columnRow += ',';
                }
    
                columnRow = columnRow.removeEnd(',');
                columnRows.add(columnRow);  
                columnRowsCSV = String.join(columnRows, '\n');
            }
        }
        return columnHeadersCSV + columnRowsCSV;
    }

    // Generate a document with the CSV content and upload to Salesforce files
    public static ConvertRecordsToCSV.Outputs generateDocument(List<String> linkedRecordIds, String documentTitle, String documentShareType, String documentVisibility, String content) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink> {};
        
        // Generate document version; This is what contains the content
        ContentVersion cv = new ContentVersion();
        cv.VersionData = Blob.valueOf(content);
        cv.Title = documentTitle;
        cv.PathOnClient = documentTitle + '.csv';
        cv.IsMajorVersion = false;
        insert cv;

        List<ContentDocument> doc = [Select Id from ContentDocument WHERE LatestPublishedVersionId =: cv.Id LIMIT 1];
        if (doc.size() == 0) {
            throw new GenerateCSVException('Document failed to generate for CSV content.');
        }

        // If the user provided linkedRecordIds, create ContentDocumentLink records for each of them; 
        // This will make the document appear in the 'Related' section of the record layout
        if (linkedRecordIds != null) {
            for (String recordId: linkedRecordIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = doc[0].Id;
                cdl.LinkedEntityId = recordId;
                if (documentShareType != null) {
                    cdl.ShareType = documentShareType;
                } else {
                    cdl.ShareType = 'AllUsers';
                }
                if (documentVisibility != null) {
                    cdl.Visibility = documentVisibility;
                } else {
                    cdl.Visibility = 'V';
                }
                links.add(cdl);
            }
            insert links;
        }

        ConvertRecordsToCSV.Outputs returnVal = new ConvertRecordsToCSV.Outputs();
        returnVal.contentDocumentId=doc[0].Id;
        returnVal.contentVersionId=cv.Id;
        returnVal.contentDocumentLinks=links;
        return returnVal;
    }
    
    // Update existing document with new version content; Used when batching a large set of records asynchronously
    public static String updateDocument(String content, String documentId) {
        List<ContentVersion> latest = [SELECT VersionData, Title FROM ContentVersion WHERE ContentDocumentId = :documentId AND IsLatest = true];
        if (latest.size() > 0) {
        	ContentVersion cv = new ContentVersion();
        	cv.VersionData = Blob.valueOf(latest[0].VersionData.toString() + content);
        	cv.Title = latest[0].Title;
        	cv.PathOnClient = latest[0].Title + '.csv';
        	cv.IsMajorVersion = false;
            insert cv;
            return cv.Id;
        }
		throw new GenerateCSVException('Unable to update document because one does not exist for id: ' + documentId);
    }

    // Transform text in certain fields to a readable string
    private static String getDisplayTextForFieldType(Object fieldValue, Schema.DisplayType fieldType) {
        if (fieldType == Schema.DisplayType.ADDRESS || fieldType == Schema.DisplayType.LOCATION) {
            // handle compound fields
            return JSON.serialize(fieldValue).escapeCsv();
        } else if (fieldType == Schema.DisplayType.DATE || fieldType == Schema.DisplayType.DATETIME) {
            return formatDateTime((String)fieldValue);
        } else {
            return String.valueOf(fieldValue).replaceAll('\r\n|\n|\r|\t',' ').escapeCsv();
        }
    }

    // Standardize date/time formatting to readable value
    private static String formatDateTime(String fieldValue) {
        // Datetime is already formatted
        if (fieldValue.contains('t') && fieldValue.contains('z') && fieldValue.indexOf('t') == 11) {
            return fieldValue;
        }
        Map<String, String> localMonthNumbers = getLocalMonthNumbers();
        Boolean isDate = false;
        for (String monthName : localMonthNumbers.keySet()) {
            if (fieldValue.contains(monthName)) {
                fieldValue = fieldValue.replaceAll(monthName, localMonthNumbers.get(monthName) + ',');
                isDate = true;
            }
        }
        if (isDate) {
            fieldValue = fieldValue.replaceAll(', ', '/');
            fieldValue = fieldValue.replaceAll('/ ', '/');
            fieldValue += ', 12:00 AM';
        }
        return Datetime.parse(fieldValue).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    // Workaround to get local month name to month number map
    private static Map<String, String> getLocalMonthNumbers() {
        Datetime dt = Datetime.newInstance(2020, 1, 1);
        Map<String, String> resultMap = new Map<String, String>();
        for (Integer i = 1; i < 12; i++) {
            String num = String.valueOf(i);
            if (num.length() == 1) {
                num = '0' + num;
            }
            resultMap.put(dt.format('MMMM').toLowerCase(), num);
            dt = dt.addMonths(1);
        }
        return resultMap;
    }
}
