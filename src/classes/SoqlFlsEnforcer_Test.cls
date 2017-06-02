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

@isTest
public class SoqlFlsEnforcer_Test {

    @isTest
    public static void testNull() {
        try {
            SoqlFlsEnforcer.validate(null);
        } catch (Exception ex) {
            System.assert(ex != null);
            System.assert(ex instanceof NullPointerException);
        }
    }

    @isTest
    public static void testDynamicSOQL() {

        String username = '%admin%';
        Boolean result = SoqlFlsEnforcer.validate('SELECT id,  email from user where name like :username');
        System.assert(result);

    }

    @isTest
    public static void testDynamicSOQLWithFunction() {
        Boolean result = SoqlFlsEnforcer.validate('SELECT Id, Name, Email, ProfileId FROM User WHERE Id =: userinfo.getUserId()');
        System.assert(result);
    }

    @isTest
    public static void testParseQuery() {
        Map<String, String> result = SoqlFlsEnforcer.getInstance().parseQuery('select a,b,c,d,e from f where g=h and i=j');
        System.debug('testParseQuery:: result -> ' + String.valueOf(result));
        System.assert(result.get('select') != null);
        System.assertEquals(result.get('select'), 'a,b,c,d,e');
        System.assert(result.get('from') != null);
        System.assertEquals(result.get('from'), 'f');
    }


    @isTest
    public static void testParseQueryWithLimit() {
        Map<String, String> result = SoqlFlsEnforcer.getInstance().parseQuery('select a,b,c,d,e from f limit 200');
        System.debug('testParseQuery:: result -> ' + String.valueOf(result));
        System.assert(result.get('select') != null);
        System.assertEquals(result.get('select'), 'a,b,c,d,e');
        System.assert(result.get('from') != null);
        System.assertEquals(result.get('from'), 'f');
    }

    @isTest
    public static void testParseQueryWithOrderAndLimit() {
        Map<String, String> result = SoqlFlsEnforcer.getInstance().parseQuery('select a,b,c,d,e from f order by g limit 200');
        System.debug('testParseQuery:: result -> ' + String.valueOf(result));
        System.assert(result.get('select') != null);
        System.assertEquals(result.get('select'), 'a,b,c,d,e');
        System.assert(result.get('from') != null);
        System.assertEquals(result.get('from'), 'f');
    }


    @isTest
    public static void testParseQueryWithOrder() {
        Map<String, String> result = SoqlFlsEnforcer.getInstance().parseQuery('select a,b,c,d,e\nfrom f\norder by a desc');
        System.debug('testParseQuery:: result -> ' + String.valueOf(result));
        System.assert(result.get('select') != null);
        System.assertEquals(result.get('select'), 'a,b,c,d,e');
        System.assert(result.get('from') != null);
        System.assertEquals(result.get('from'), 'f');
    }


    @isTest
    public static void testParseWhereDynamic() {
        Set<String> result = SoqlFlsEnforcer.getInstance().parseWhere('a=:x and b>=\'%United States%\' or c in :z and d != :test');
        System.debug('testParseWhere:: result -> ' + String.valueOf(result));
        System.assert(result.contains('A'));
        System.assert(result.contains('B'));
        System.assert(result.contains('C'));
        System.assert(result.contains('D'));

        result = SoqlFlsEnforcer.getInstance().parseWhere('foo=:x and liked__c>=:y or mapping__c in :z and doo != :test');
        System.debug('testParseWhere:: result -> ' + String.valueOf(result));
        System.assert(result.contains('MAPPING__C'));
        System.assert(result.contains('LIKED__C'));
        System.assert(result.contains('FOO'));
        System.assert(result.contains('DOO'));



        result = SoqlFlsEnforcer.getInstance().parseWhere(' Id =: userinfo.getUserId()');
        System.debug('testParseWhere:: result -> ' + String.valueOf(result));
        System.assert(result.contains('ID'));


    }

    @isTest
    public static void testExecuteSuccessful() {
        // Contact
        Boolean contactResult = SoqlFlsEnforcer.getInstance().execute('SELECT firstName, lastName FROM Contact');
        System.assert(contactResult);
        // Lead
        Boolean leadResult = SoqlFlsEnforcer.getInstance().execute('SELECT firstName, lastName FROM Lead');
        System.assert(leadResult);
        
    }

    @isTest
    public static void testSelectCount() {
        // Select count not supported, not required
        Boolean contactResult = SoqlFlsEnforcer.getInstance().execute('SELECT count(id) FROM Contact');
        System.assert(contactResult);
    }

    @isTest
    public static void testSelectCountWhere() {
        // Select count not supported, not required
        Boolean contactResult = SoqlFlsEnforcer.getInstance().execute('SELECT count(id) FROM Contact where firstName in :listoffields');
        System.assert(contactResult);
    }

    @isTest
	public static void testComplexFormattedQuery() {
		String complexFormattedQuery = 'SELECT Id FROM opportunity ' +
                            				'WHERE (' +
                                			'(CreatedById = :vrecid) OR ' +
                                			'(OwnerId = :vrecid) OR ' +
                                			'(LastModifiedById = :vrecid)' +
                            				')' +
                            				'AND (' +
                                			'(CreatedById = :vMasterid AND StageName = \'Closed Won\') OR ' +
                                			'(OwnerId = :vMasterid AND StageName = \'Won\') OR ' +
                                			'(LastModifiedById = :vMasterid AND StageName = \'Prospecting\')' +
                            				')  LIMIT 1';

        Boolean result = SoqlFlsEnforcer.validate(complexFormattedQuery);
        System.assert(result);
    }

    @isTest
    public static void testExample() {
        String query = 'select Account.name, Birthdate, FirstName, HomePhone, LastName from Contact where birthdate > 1950-01-01';
        if (!SoqlFlsEnforcer.validate(query)) throw new NoAccessException();
        List<Contact> contactList = Database.query(query);
    }

}