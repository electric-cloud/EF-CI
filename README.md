# EF-CI

ef-ci.pl is Perl script that checks continuously for any change in a project directory structure (like the [DSL-SLurper](http://github.com/electric-cloud/DSL-slurper)) and save the modified file as the command of a step.
The path to the step files indicates to the system in which exact location to save this command.
If if detect some *.ntest files, it will also run [ec-testing](http://github.com/electric-cloud/ec-testing)::ntest

This allows you to shorten your development cycle by avoiding to copy command back and forth between the command field editor and a real text editor or IDE.

The structure of the directory should be:

PROJECT_NAME
  procedures
    PROC1_NAME
      steps
        step1_1.pl
        step1_2.sh
    PROC2_NAME
      steps
        step2_1
        step2_2
        step2_3
        
The system also work with a file structure created by [EC-Admin](http://github.com/electric-cloud/EC-Admin)::projectAsCode. in this case the strcuture looks like

PROJECT_NAME
  src
    project
      procedures
        PROC1_NAME
          steps
            step1_1
...

It basically runs ectool setProperty command --projectName PROJECT_NAME --procedureName PROC1_name --stepName step1_1 --valueFile /path/to/step1_1
