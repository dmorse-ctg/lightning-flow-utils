global without sharing class ConvertRecordsToCSV {

    class GenerateCSVException extends Exception {}

    private static Integer SYNC_ITERATION_LIMIT = 200000;

    global class Inputs {
        @InvocableVariable(description='List of sObject records to print in report' required=true)
        global List<SObject> inputCollection;
    
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

        @InvocableVariable(description='Id of the asynchronous job queued. If the action was executed asynchronously all other return values will be null')
        global ID asyncJobId;
    }

    @InvocableMethod(label='Generate sObject CSV Report' description='Generates a CSV of all sObject field values for the list provided. Generates a document and optionally links it to the related object provided.' category='Reporting')
    public static List<GenerateSObjectCSV.Outputs> generateCSV(List<GenerateSObjectCSV.Inputs> inputVariables) {
        if (inputVariables.size() == 0) {
            throw new GenerateCSVException('No input variables provided.');
        }

        List<String> fieldsList = inputVariables[0].fieldsCollection;
        if (inputVariables[0].fieldsString != null) {
            fieldsList = inputVariables[0].fieldsString.split(',');
            if (fieldsList.size() == 0) {
                throw new GenerateCSVException('Invalid list of primary fields provided. The string is not comma separated.');
            }
        }

        List<String> linkedRecordIds = inputVariables[0].linkedRecordIds;
        if (inputVariables[0].linkedRecordIdsString != null) {
            linkedRecordIds = inputVariables[0].linkedRecordIdsString.split(',');
            if (linkedRecordIds.size() == 0) {
                throw new GenerateCSVException('Invalid list of linked record ids provided. The string is not comma separated.');
            }
        }

        Boolean executeAsync = inputVariables[0].executeAsynchronously == null ? false: inputVariables[0].executeAsynchronously;
        if (!executeAsync && fieldsList != null && fieldsList.size()*input.inputCollection.size() > SYNC_ITERATION_LIMIT) {
            throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
        }
        if (!executeAsync) {
            String fullCSV = generateCSVContent(inputVariables[0].inputCollection, fieldsList);
            GenerateSObjectCSV.Outputs returnVal = generateDocument(inputVariables[0].linkedRecordIds, inputVariables[0].documentTitle, inputVariables[0].documentShareType, inputVariables[0].documentVisibility, fullCSV);
            return new List<GenerateSObjectCSV.Outputs>{returnVal};
        }
        ID jobId = System.enqueueJob(new GenerateCSVContentQueueable(inputVariables[0].inputCollection, fieldsList, inputVariables[0].linkedRecordIds, inputVariables[0].documentTitle, inputVariables[0].documentShareType, inputVariables[0].documentVisibility));
        Outputs returnVal = new Outputs();
        returnVal.asyncJobId = jobId;
        return new List<GenerateSObjectCSV.Outputs>{returnVal};
    }

    public static String generateCSVContent(List<SObject> objectList, List<String> fieldList, Bool executingAsync) {
        if (objectList[0].getSObjectType().getDescribe().getName() == 'AggregateResult') { 
            // Handle AggregateResult type
            return generateAggregateResultCSV(objectList, fieldList, executingAsync);
        }
        // Handle regular sObject
        return generateSObjectCSV(objectList, fieldList, executingAsync);
    }

    @TestVisible
    private static String generateAggregateResultCSV(List<SObject> objectList, List<String> fieldList, Boolean executingAsync) {
        Set<String> columnHeaders = new Set<String>{};
        List<String> columnRows = new List<String>{};

        // If primary fields were provided, set them to the column values
        if (fieldList != null) {
            columnHeaders = new Set<String>(fieldList);
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
        } else {
            // Else, get union of all populated field names
            List<Map<String, Object>> soFieldList = new List<Map<String, Object>>{};
            for (AggregateResult result: (List<AggregateResult>)objectList) {
                soFieldList.add((Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(result)));
            }

            for (Map<String, Object> data: soFieldList) {
                columnHeaders.addAll(data.keySet());
            }

            // Check limits
            if (!executingAsync && columnHeaders.size()*input.inputCollection.size() > SYNC_ITERATION_LIMIT) {
                throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
            }

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
        }

        String columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
        return columnHeadersCSV + String.join(columnRows, '\n');
    }

    @TestVisible
    private static String generateSObjectCSV(List<SObject> objectList, List<String> fieldList, Boolean executingAsync) {
        Set<String> columnHeaders = new Set<String>{};
        List<String> columnRows = new List<String>{};

        // If primary fields were provided, set them to the column values
        if (fieldList != null) {
            columnHeaders = new Set<String>(fieldList);
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
                if (!executingAsync && columnHeaders.size()*input.inputCollection.size() > SYNC_ITERATION_LIMIT) {
                    throw new GenerateCSVException('The batch size you have provided is too large to execute synchronously. Please reduce the number of columns or rows or run execute this action asynchronously.');
                }
            }

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
        }
        String columnHeadersCSV = String.join(new List<String>(columnHeaders), ',') + '\n';
        return columnHeadersCSV + String.join(columnRows, '\n');
    }

    public static GenerateSObjectCSV.Outputs generateDocument(List<String> linkedRecordIds, String documentTitle, String documentShareType, String documentVisibility, String content) {
        ContentVersion cv = new ContentVersion();
        cv.VersionData =  Blob.valueOf(content);
        cv.Title = documentTitle;
        cv.PathOnClient = documentTitle + '.csv';
        cv.IsMajorVersion = true;
        insert cv;

        List<ContentDocument> doc = [Select Id from ContentDocument WHERE LatestPublishedVersionId =: cv.Id LIMIT 1];
        if (doc.size() == 0) {
            throw new GenerateCSVException('Document failed to generate for CSV content.');
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink> {};
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

        GenerateSObjectCSV.Outputs returnVal = new GenerateSObjectCSV.Outputs();
        returnVal.contentDocumentId=doc[0].Id;
        returnVal.contentVersionId=cv.Id;
        returnVal.contentDocumentLinks=links;
        return returnVal;
    }

    private static String getDisplayTextForFieldType(Object fieldValue, Schema.DisplayType fieldType) {
        if (fieldType == Schema.DisplayType.ADDRESS || fieldType == Schema.DisplayType.LOCATION) {
            // handle compound fields
            return JSON.serialize(fieldValue).escapeCsv();
        } else if (fieldType == Schema.DisplayType.DATE || fieldType == Schema.DisplayType.DATETIME) {
            return formatDateTime((String)fieldValue);
        } else {
            return String.valueOf(fieldValue).replaceAll('\r\n|\n|\r',' ').escapeCsv();
        }
    }

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
            fieldValue += ', 00:00 AM';
        }
        return Datetime.parse(fieldValue).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    //Workaround to get local month name to month number map
    private static Map<String, String> getLocalMonthNumbers() {
        Datetime dt = Datetime.newInstance(2020, 1, 1);
        Map<String, String> resultMap = new Map<String, String>();
        for (Integer i = 1; i < 12; i++) {
            resultMap.put(dt.format('MMMM').toLowerCase(), String.valueOf(i));
            dt = dt.addMonths(1);
        }
        return resultMap;
    }
}
