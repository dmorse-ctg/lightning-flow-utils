global with sharing class FilterByRelatedRecords {
    global class FilterCriteria {
        @InvocableVariable
        global String targetFieldName;
        @InvocableVariable
        global String comparitorFieldName;
   		@InvocableVariable(description='Valid values: =, !=, >, <, >=, <=')
        global String comparitor;
    }
    
    global class Request {
        @InvocableVariable(description='Target collection to filter' required=true)
        global List<SObject> targetCollection;

        @InvocableVariable(description='Comparitor collection to filter against' required=true)
        global List<SObject> compareToCollection;

        @InvocableVariable(description='List of filter criteria' required=true)
        global List<FilterCriteria> filterOnFieldNames;
    }

    global class Result {
        global List<SObject> filteredCollection;
    }

    global static List<Result> filterByRelatedRecords(List<Request> requestList) {
        List<Result> results = new List<Result>{};
        for (Request request: requestList) {
            List<SObject> filteredList = new List<SObject>{};
            for (SObject compareRecord: request.compareToCollection) {
                for (SObject filterRecord: request.targetCollection) {
                    Boolean filterMatch = true;
                    for (FilterCriteria criteria: request.filterOnFieldNames) {
                        if (!compare(String.valueOf(filterRecord.get(criteria.targetFieldName)), String.valueOf(compareRecord.get(criteria.comparitorFieldName)), criteria.comparitor)) {
                            filterMatch = false;
                            break;
                        }
                    }
                    if (filterMatch) {
                        filteredList.add(filterRecord);
                    }
                }
                Result result = new Result();
                result.filteredCollection = filteredList;
                results.add(result);
            }
        }
        return results;
    }
    
    private static Boolean compare(String val1, String val2, String comparitor) {
        switch on comparitor {
            when '=' {
                return val1 == val2;
            }
            when '!=' {
                return val1 != val2;
            }
            when '>' {
                return val1 > val2;
            }
            when '<' {
                return val1 < val2;
            }
            when '<=','=<' {
                return val1 <= val2;
            }
            when '>=', '=>' {
                return val1 >= val2;
            }
        }
        return false;
    }
}