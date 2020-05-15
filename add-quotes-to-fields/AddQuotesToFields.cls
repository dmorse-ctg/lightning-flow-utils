global without sharing AddQuotesToFields {
    global class Input {
        @InvocableVariable(description='Collection of records to transform')
        List<String> fieldCollection;

        @InvocableVariable(description='Comma separated string of records to transform')
        String fieldString;

        @InvocableVariable(description='Valid inputs are SINGLE for single quotes or DOUBLE for double quotes; Default value is SINGLE.')
        String quoteType;
    }

    global class Output {
        @InvocableVariable(description='Collection of records transformed with quotes')
        List<String> fieldCollection;

        @InvocableVariable(description='Comma separated string of records transformed with quotes')
        String fieldString;
    }

    @InvocableMethod(description='Add qoutes to each element in a collection')
    global static Result addQuotesToCollection(List<Input> input) {
        List<Output> outputs = new List<Output>{};
        for (Input input: inputs) {
            if (input.fieldString != null && input.fieldString.length() > 0) {
                input.fieldCollection = input.fieldString.split(',');
            }
            if (input.quoteType == null) {
                input.quoteType = 'SINGLE';
            }
            for (String field: input.fieldCollection) {
                
                if (input.quoteType == 'DOUBLE') {
                    field = '"' + String.escapeSingleQuotes(field) + '"';
                } else {
                    field = '\'' + String.escapeSingleQuotes(field) + '\'';
                }
            }
            Output output = new Output();
            output.fieldCollection = input.fieldCollection;
            output.fieldString = String.join(input.fieldCollection, ',');
            outputs.add(output);
        }
        return outputs;
    }
}