var salesforce = {
  username: '',
  password: '',
  serverurl: '',
};

module.exports = function(grunt) {
  grunt.initConfig({

    salesforce: grunt.file.readJSON('.credential'),

    prompt: {
      server: {
        options: {
          questions: [{
            config: 'sf.server',
            type: 'list',
            message: 'which server?',
            default: 'https://test.salesforce.com',
            choices: ['https://test.salesforce.com', 'https://login.salesforce.com'],
            filter: function(value) {
              salesforce.serverurl = value;
              return value;
            }
          }]
        }
      },

      credential: {
        options: {
          questions: [{
            config: 'sf.username',
            type: 'input',
            message: 'username:',
            validate: function(value) {
              salesforce.username = value;
              if (value == '') {
                return 'username required';
              }
              return true;
            }
          }, {
            config: 'sf.password',
            type: 'password',
            message: 'password:',
            validate: function(value) {
              salesforce.password = value;
              if (value == '') {
                return 'password required';
              }
              return true;
            }
          }]
        }
      }
    },

    
    antdeploy: {
      options: {
        root: './src',
        apiVersion: '36.0',
        existingPackage: true,
        pollWaitMillis: 1000*60,
        maxPoll: 300,
        user: '<%=salesforce.username%>',
        pass: '<%=salesforce.password%>',
        serverurl: '<%=salesforce.serverurl%>'
      },
      deployOnly: {
        options: {
          runAllTests: false
        }
      },
      deployAndTest: {
        options: {
          runAllTests: true
        }
      }
    },

    antretrieve: {
      options: {
        apiVersion: '36.0',
        existingPackage: true,
        pollWaitMillis: 1000*60,
        maxPoll: 300,
        user: '<%=salesforce.username%>',
        pass: '<%=salesforce.password%>',
        serverurl: '<%=salesforce.serverurl%>'
      },
      all: {
        options: {
          root: './retrieve',
        }
      }
    },

    mkdir: {
      all: {
        options: {
          create: ['retrieve']
        }
      }
    },

    copy: {
      all: {
        files: {
          'retrieve/package.xml': ['src/package.xml']
        }
      }
    }

  });

  grunt.loadNpmTasks('grunt-ant-sfdc');
  grunt.loadNpmTasks('grunt-prompt'); 
  grunt.loadNpmTasks('grunt-mkdir');
  grunt.loadNpmTasks('grunt-copy');

  grunt.registerTask('who', function() {
    grunt.log.writeln('username....: ' + grunt.config.get('salesforce.username'));
    grunt.log.writeln('server url..: ' + grunt.config.get('salesforce.serverurl'));
  });

  grunt.registerTask('write-json', function() {
    grunt.file.write('.credential', JSON.stringify(salesforce));
  });

  grunt.registerTask('login', ['prompt:server', 'prompt:credential', 'write-json']);  
  grunt.registerTask('deploy', ['antdeploy:deployOnly']);
  grunt.registerTask('deploytest', ['antdeploy:deployAndTest']);
  grunt.registerTask('default', ['deploy']);
  

};
