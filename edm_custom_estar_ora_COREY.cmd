:=======================================================================:
: Eagle  Investments Systems                                            :
: Custom ESTAR Schema Upgrade                                           :
:                                                                       :
: Author   : Kumar Potluri,   Eagle Investment Systems                  :
: Database : Oracle 10g or Higher                                       :
: Script   : edm_standard_command_ora.cmd                               :
: Desc     : Command script for Upgrading Eagle DB to 11.0              :
:                                                                       :
: ChangeLog:                                                            :
: Version#     Author              ModifiedDate      Tested By          :
: Version 1.0  Kumar Potluri       03/20/2010        Uma K              :  
:                                                                       :
: Install Scripts on any New Custom Estar Schema in lieu of ESTAR Schema:
: Replace line number 87 with below line of code                        :
: set control_file=install\edm_control_file_ora.txt                     :
:                                                                       :
: Important point to remember and rectify if required                   :
: In script control file directory column "common" should not have any  :
: spaces before or after. If you find any please remove them before exec:
:                                                                       :
: Errors relating to below tables are to be ignored because synonyms    :
: were created for these tables in custom Estar Schemas                 :
: Owner Synonym Name                 TblOwner Table_Name                :
: ARIC  CCID_RULE                    ESTAR  CCID_RULE                   :
: ARIC  CCID_RULE_DETAIL             ESTAR  CCID_RULE_DETAIL            :
: ARIC  ESTAR_EARNTHRU_RULE_DTL      ESTAR  ESTAR_EARNTHRU_RULE_DTL     :
: ARIC  ESTAR_EARNTHRU_RULE_DTL_JRNL ESTAR  ESTAR_EARNTHRU_RULE_DTL_JRNL:
: ARIC  ESTAR_EARNTHRU_RULE_HDR      ESTAR  ESTAR_EARNTHRU_RULE_HDR     :
: ARIC  ESTAR_EARNTHRU_RULE_HDR_JRNL ESTAR  ESTAR_EARNTHRU_RULE_HDR_JRNL:
:                                                                       :
: Notes (Corey): Script changed 7/29/2016 (pace_master packages)        :
:=======================================================================:
: create role EAGLE_APP_CONNECT_ROLE;
: GRANT EAGLE_APP_CONNECT TO COREY WITH ADMIN OPTION;
: GRANT EAGLE_APP_CONNECT_ROLE TO COREY WITH ADMIN OPTION;
: Replace common | with common| for edm_control_file_ora.txt

@echo off

rem Get input values

:set SERVER_NAME=%1
:set USERID=%2
:set CUSTOMPW=%3

set SERVER_NAME=mfdb
set USERID=corey
set CUSTOMPW=eagle

rem Delete old sql output files

if exist *.out del *.out
if exist *.LOG del *.LOG
if exist temporary_ora_sql.sql del temporary_ora_sql.sql

rem Check input values for null values

:check_param
if "%SERVER_NAME%" == "" goto no_server
if "%USERID%" == "" goto no_userid
if "%CUSTOMPW%" == "" goto no_password

rem Generate output file names using given mssql database server name

set MOD_SERVER_NAME=
for /f "tokens=1,2 delims=\ " %%a in ("%SERVER_NAME%") do (
if not "%%a" == "" set MOD_SERVER_NAME=%%a_
if not "%%b" == "" set MOD_SERVER_NAME=%%a_%%b_)

set DATE1=
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do (set DATE1=%%d%%b%%c)
set TIME1=
for /F "tokens=1-4 delims=:., " %%a in ("%TIME%") do (set TIME1=%%a%%b%%c)
set CONSOLIDATE_LOG=%MOD_SERVER_NAME%%USERID%_UPGRADE_LOG_%DATE1%%TIME1%.LOG
set ERROR_LOG=%MOD_SERVER_NAME%%USERID%_UPGRADE_ERROR_LOG_%DATE1%%TIME1%.LOG
set EXECUTION_LOG=%MOD_SERVER_NAME%%USERID%_UPGRADE_EXECUTION_LOG_%DATE1%%TIME1%.LOG

rem Check input values for successful login

:check_login
echo Checking login information on %SERVER_NAME% ...
sqlplus -s %USERID%/%PASSWORD%@%SERVER_NAME% < select 'DB_CHECK_SUCCESS' from dual; >> %CONSOLIDATE_LOG% 
IF %ERRORLEVEL% == 0 GOTO continue
IF %ERRORLEVEL% NEQ 0 GOTO try_again

:continue

echo Upgrading %USERID% schema on database on %SERVER_NAME% to current version

rem Assign db scripts control file name to local variable

rem Kumar - path change for ora12 accounting development schemas
set control_file=upgrade\edm_control_file_ora.txt

rem Kumar - run an alternate revoke script for ora12 accounting development schemas

rem drop edm_revoke_with_grant_option table not to revoke required grants from pace_masterdbo
echo drop edm_revoke_with_grant_option table not to revoke required grants from pace_masterdbo
call execute_ora.cmd estar edm_ecustom_drop_revoke_wgo_table_ora.sql null null eagle_temp eagle

rem Procedure edm_create_synonym_sp has been customized for not cosidering partition control table last ddl date and time

echo Run estar edm_ecustom_create_synonym_sp_ora.sql
call execute_ora.cmd estar edm_ecustom_create_synonym_sp_ora.sql null null %USERID% %CUSTOMPW%

rem Read info from control file about script files to be executed and corresponding database names in a loop

for /f "eol=- tokens=1,2,3,4,5,6,7 delims=|" %%i in (%control_file%) do ( 
if "%%i" == "END_OF_CONTROL_FILE" goto create_horizontal_synonyms 
if not "%%i" == "edm_wait" call execute_ora.cmd %%j %%n\%%k %%l %%m %USERID% %CUSTOMPW%
)

:create_horizontal_synonyms

call execute_ora.cmd estar edm_ecustom_create_synonym_script_ora.sql null null %USERID% %CUSTOMPW%

goto end_of_process

:end_of_control_file

goto success

:no_server
set SERVER_NAME=
set USERID=
set PASSWORD=
set /P SERVER_NAME=Please enter the DB Server Name:
set /P USERID=Please enter the User Name     :
set /P CUSTOMPW=Please enter the password      :
goto check_param

:no_userid
set /P USERID=Please enter the Estar Schema Name ?
goto check_param

:no_password
set /P CHK_PASS=The password entered is NULL, is this correct [Y/N]?
if /I "%CHK_PASS%" == "Y" goto check_login
set /P CUSTOMPW=Please enter the password for %USERID%?
goto check_param

:invalid_option
echo ERROR. You have selected an invalid option.
echo Press any key to create log files
pause >nul
goto done

:success
set LOG_FILES_NAME=
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do (set LOG_FILES_NAME=LOG_FILES_%%d%%b%%c.out )

echo Database Upgrade scripts complete!
echo Please check %ERROR_LOG% for any errors.
echo Please review %CONSOLIDATE_LOG% for database changes or more details about errors

goto done

:try_again

set /P LOGIN_AGAIN=ERROR: Login failed, do you want to try again [Y/N]?
if /I "%LOGIN_AGAIN%" == "Y" goto no_server

:done
set DATE1=
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do (set DATE1=%%d%%b%%c)
set TIME1=
for /F "tokens=1-4 delims=:., " %%a in ("%TIME%") do (set TIME1=%%a%%b%%c)
set LOG_FILES=LOG_FILES_%DATE1%_%TIME1%.OUT

:end_of_process

rem Corey - Using grep command from cygwin install

findstr /i /b /n /G:search_for_error_strings.txt %CONSOLIDATE_LOG% > %ERROR_LOG%.orig.log
findstr /V "ORA\-01926" %ERROR_LOG%.orig.log | findstr /V "Eagle Error:" > %ERROR_LOG%

rem Corey - move the log files to the logs directory

echo Moving log files to logs:
if not exist logs md logs
move /Y *.out logs > nul
move /Y *.log logs > nul

echo %CONSOLIDATE_LOG%
echo Please press any key to exit
pause >nul

