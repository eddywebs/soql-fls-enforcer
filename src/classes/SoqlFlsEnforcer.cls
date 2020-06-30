/*
 * Copyright 2017 Loong Fei, Amir Hamzah, Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to 
 * deal in the Software without restriction, including without limitation the 
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
 * sell copies of the Software, and to permit persons to whom the Software is 
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in 
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM
 * , OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
 * THE SOFTWARE.
 */

/**
 * Validate SOQL FLS access using FLSCheckUtil class. Parse SOQL query to list all the fields to be validated
 * to ensure all fields specified is readable.
 */
public with sharing class SoqlFlsEnforcer {
	private final String NAMESPACE = 'YourNamespaceIfAny';
	private static SoqlFlsEnforcer instance = null;	
	private String namespacePrefix = null;
	private String soqlRegex = 	'(?i)(SELECT[\\s]+.*[\\s]+)' +
	                            '(FROM[\\s]+[\\w]+[\\s]*)' +
	                            '(WHERE[\\s]+.*[\\s]*){0,1}' +
	                            '(ORDER[\\s]+.*[\\s]*){0,1}' +
	                            '(LIMIT[\\s]+[\\d]+){0,1}' +
	                            '(OFFSET[\\s]+[\\d]+){0,1}';

	private SoqlFlsEnforcer() {
		Integer sizeOfNS = [select NamespacePrefix from PackageLicense where NamespacePrefix = :NAMESPACE].size();

		if (sizeOfNS == 1) {
			namespacePrefix = NAMESPACE + '__';
		} else {
			namespacePrefix = [SELECT NamespacePrefix FROM Organization].NamespacePrefix;
			if (namespacePrefix != null) namespacePrefix = namespacePrefix + '__';	
		}
		
	}

	public static Boolean validate(String query) {
		return SoqlFlsEnforcer.getInstance().execute(query);
	}

	public static SoqlFlsEnforcer getInstance() {
		if (instance == null) {
			instance = new SoqlFlsEnforcer();
		}
		return instance;
	}


	/**
	 * Validate the query it is authorize to view the object.
	 *
	 * @throw NoAccessException when the query are not authorize.
	 * @throw QueryException when the Query is malformed.
	 * @throw NullPointerException when the query is Null.
	 */
	public Boolean execute(String query) {
		Map<String, String> queryMap = null;
		Set<String> fieldSet = null;
		List<String> fieldList = null;
		Set<String> whereSet = null;
		SObjectType objectType = null;
		Boolean result = false;

		if (query == null) {
			throw new NullPointerException();
		}

		queryMap = parseQuery(query);

		// Select
		fieldSet = parseSelect(queryMap.get('select'));


		// From
		objectType = Schema.getGlobalDescribe().get(queryMap.get('from'));

		// Where
		if (queryMap.get('where') != null) {
			whereSet = parseWhere(queryMap.get('where'));
			//System.debug('execute:: whereSet -> ' + String.valueOf(whereSet) );
			// Merge the field list
			fieldSet.addAll(whereSet);
		}

		// Cast fieldSet to fieldList and Clean
		fieldList = new List<String>(cleanFieldSet(fieldSet));

		System.debug('execute:: fieldList -> ' + String.valueOf(fieldList) +
				  '\n        objectType -> ' + String.valueOf(objectType));

		if (fieldList.size() == 0) {
			result = true; // Select count without filter
		} else  {
			result = false; //replace this with FLSCheckutil //ESAPI.accessController().isAuthorizedToView(objectType, fieldList);
		}

		return result;
	}


	/**
	 * Clean the set of fields, looking for lookup field and field with unexpected character.
	 *
	 * @return Set fo clean field.
	 */
	private Set<String> cleanFieldSet(Set<String> fieldSet) {
		Set<String> result = new Set<String>();
		for (String field : fieldSet) {
			if (!String.isBlank(field)) { // Blank field will be ignored.
				field = field.replaceAll('__R\\.[\\w]+', '__C'); // Custom Lookup Field
				field = field.replaceAll('\\.[\\w]+', 'ID'); // Standard Lookup Field
				field = field.replaceAll('\\(|\\)', '');
				result.add(field);
			}
		}
		return result;
	}

	/**
	 * Parse the Select clause, ignoring count.
	 *
	 * @return Set of fields from the Select statement. Empty set if it is a Select Count.
	 */
	private Set<String> parseSelect(String selectClause) {
		Set<String> fieldSet = null;
		List<String> fieldList = null;
		selectClause = selectClause.toUpperCase();
		fieldSet = new Set<String>(selectClause.split('[\\s]*,[\\s]*'));
		fieldList = new List<String>(fieldSet);

		// Remove Select Count
		if (fieldList.size() == 1 && fieldList[0].startsWithIgnoreCase('COUNT')) {
			fieldSet.clear();
		}

		return fieldSet;
	}

	/**
	 * Parse the where clause to extract all the fields.
	 *
	 * @return Set of fields from the Where clause.
	 */
	@TestVisible
	private Set<String> parseWhere(String whereClause) {
		Set<String> whereSet = new Set<String>();
		String locateFieldRegex = '(?i)([\\w]+[\\s]*[<>=!]{1,2})|([\\w]+[\\s]+(like\\b|in\\b){1})';
		String cleanFieldRegex = '(?i)([\\s]*[<>=!]{1,2})|([\\s]+(like\\b|in\\b){1})';
		String field;


		whereClause = whereClause.toUpperCase();

		// System.debug('parseWhere:: whereClause -> ' + whereClause);

		Pattern soqlPattern = Pattern.compile(locateFieldRegex);
		Matcher soqlMatcher = soqlPattern.matcher(whereClause);

		while (soqlMatcher.find()) {
			field = soqlMatcher.group();
			//System.debug('parseWhere:: found --> ' + field);
			if (! String.isBlank(field)) {
				field = field.replaceAll(cleanFieldRegex, '');
				//System.debug('parseWhere:: cleaned --> ' + field);
				whereSet.add(field);
			}

		}

		// System.debug('parseWhere:: whereSet -> ' + String.valueOf(whereSet));

		return whereSet;

	}


	/**
	 * Parse the SOQL query and break down into 3 parts and store in a Map. The map consist of the following:
	 *
	 * <ul> select -> List of selected fields separated by Comma
	 * <ul> from -> object name
	 * <ul> where -> Fieldname use in the Where clause.
	 *
	 * @return Map of 4 key value pair. The keys are: 'select', 'from', 'where' and 'order'
	 */
	@TestVisible
	private Map<String, String> parseQuery(String query) {
		Map<String, String> result = null;
		String fields = null;
		String objectname = null;
		String filter = null;
		String order = null;
		Pattern soqlPattern = Pattern.compile(soqlRegex);
		Matcher soqlMatcher = soqlPattern.matcher(query);


		result = new Map<String, String>();

		System.debug('::parseQuery query -> ' + query);

		soqlMatcher.reset();
		while (soqlMatcher.find()) {
			// Get all the field name separated by comma without white spaces
			fields = soqlMatcher.group(1);
			if (fields == null) throw new QueryException();
			fields = fields.replaceAll('(?i)(SELECT[\\s]+)|[\\s]+', '');

			// Get the Object name
			objectname = soqlMatcher.group(2);
			if (objectname == null) throw new QueryException();
			objectname = objectname.replaceAll('(?i)(FROM[\\s]+)|[\\s]+', '');
			

			// Optional, where clause
			filter = soqlMatcher.group(3);
			filter = filter == null ? null : filter.replaceAll('(?i)[\\s]*WHERE[\\s]+', '');

			// Order clause
			order = soqlMatcher.group(4);

		}

		// Append namespace to Object name
		if (objectname.containsIgnoreCase('__c') && 
			namespacePrefix != null &&
			!objectname.startsWithIgnoreCase(namespacePrefix)) {

			objectname = namespacePrefix + objectname;
		}

		// Append namespace to Field name
		if (fields.containsIgnoreCase('__c') && 
			namespacePrefix != null &&
			!fields.containsIgnoreCase(namespacePrefix)) {
			fields = fields.replaceAll('(?i)[\\w]+(__c|__r)',namespacePrefix + '$0');
		}

		// Append namespace to Field name for Filter
		if (filter != null && filter.containsIgnoreCase('__c') && 
			namespacePrefix != null && 
			!filter.containsIgnoreCase(namespacePrefix)) {

			filter = filter.replaceAll('(?i)[\\w]+(__c|__r)',namespacePrefix + '$0');
		}

		result.put('select', fields);
		result.put('from', objectname);
		result.put('where', filter);
		result.put('order', order);

		return result;
	}

}
