# Force.com SOQL FLS Enforcer

FLS Enforcement checks using SOQL statement. We came up with this solution when 
we try to implement FLS Enforcement in existing code base with almost a 
thousand of SOQL query in the code.

## Installation
### Prerequisite
1. Ensure [Force.com ESAPI](https://github.com/forcedotcom/force-dot-com-esapi.git) 
   is install in your Salesforce Org
2. Ensure Java8 JDK is installed. [https://java.com/en/download/]
3. Ensure Gruntjs installed.
   * Install NPM: https://www.npmjs.com/get-npm
   * Install Gruntjs:
    
     ```
     npm install -g grunt-cli
     ```

### Code Deployment

1. With NPM installed, execute the following command to get all the 
   dependencies:
   
    ```
    npm install
    ```

2. Then enter the following command and follow the instructions to persist your
   credential 
   
    ```
    grunt login
    ```

   * The entered credential will have the following format in ```.credential```
   
   ```
   {"username":"user@example.com","password":"secret","serverurl":"https://test.salesforce.com"}
   ```
   
3. To deploy, enter the following command:

    ```
    grunt 
    ```

## Getting Started

Here is how ```SoqlFlsEnforcer``` can be used to determine if the fields in the
SOQL is viewable by the context user.

Exampe:

```java
String query = 'select Account.name, Birthdate, FirstName, HomePhone, LastName' + 
               'from Contact where birthdate > 1950-01-01';
if (!SoqlFlsEnforcer.validate(query)) throw new NoAccessException();
List<Contact> contactList = Database.query(query);

```

## Contributing
1. Branch it!, refer to https://datasift.github.io/gitflow/IntroducingGitFlow.html

## Credits
* Loong Fei - http://github.com/RoninCWalker
* Amir Hamzah- https://github.com/amirkhalid
