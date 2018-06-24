:: Name:      buildWebRTC.bat
:: Purpose:   Builds WebRTC lib
:: Author:    Sergej Jovanovic
:: Email:     sergej@gnedo.com
:: Twitter:   @JovanovicSergej
:: Revision:  December 2017 - initial version

@ECHO off
SETLOCAL EnableDelayedExpansion

SET CONFIGURATION=%1
SET PLATFORM=%2
SET CPU=%3
SET SOFTWARE_TARGET=%4
SET msVS_Path=""
SET failure=0
SET x86BuildCompilerOption=amd64_x86
SET x64BuildCompilerOption=amd64
SET armBuildCompilerOption=amd64_arm
SET x86Win32BuildCompilerOption=amd64_x86
SET x64Win32BuildCompilerOption=amd64
SET currentBuildCompilerOption=amd64

::log levels
SET logLevel=4                      
SET error=0                           
SET info=1                            
SET warning=2                         
SET debug=3                           
SET trace=4 

If /I "%SOFTWARE_TARGET%"=="" (
  echo Usage: buildWebRTC [debug/release] [winuwp/win32] [x86,x64,arm] [webrtc/ortc]
  CALL bin\batchTerminator.bat
)

IF /I "%CPU%"=="win32" SET CPU=x86
IF /I "%CPU%"=="arm" (
  IF /I "%PLATFORM%"=="win32" (
    CALL:print %info% "Win32 ARM is not a valid target thus building for x86 cpu ..."
    SET CPU=x86
  )
)

SET startTime=0
SET endingTime=0

SET baseBuildPath=webrtc\xplatform\webrtc\out

CALL:print %info% "Webrtc build is started. It will take couple of minutes."
CALL:print %info% "Working ..."

SET currentPlatform=%PLATFORM%
SET currentCpu=%CPU%
SET linkPlatform=%currentPlatform%
SET linkCpu=%currentCpu%

CALL:print %info%  "%PLATFORM%"
CALL:print %info%  "%CPU%"
CALL:print %info%  "Platform !currentPlatform!"
CALL:print %info%  "Cpu !currentCpu!"

SET startTime=%time%

CALL:determineVisualStudioPath

CALL:setCompilerOption %currentPlatform% %currentCpu%

CALL:buildNativeLibs

CALL:makeOutputLinks

GOTO:done

:determineVisualStudioPath

SET progfiles=%ProgramFiles%
IF NOT "%ProgramFiles(x86)%" == "" SET progfiles=%ProgramFiles(x86)%

REM Check if Visual Studio 2017 is installed
SET msVS_Path="%progfiles%\Microsoft Visual Studio\2017"
SET msVS_Version=14

IF EXIST !msVS_Path! (
	SET msVS_Path=!msVS_Path:"=!
	IF EXIST "!msVS_Path!\Community" SET msVS_Path="!msVS_Path!\Community"
	IF EXIST "!msVS_Path!\Professional" SET msVS_Path="!msVS_Path!\Professional"
	IF EXIST "!msVS_Path!\Enterprise" SET msVS_Path="!msVS_Path!\Enterprise"
	IF EXIST "!msVS_Path!\VC\Tools\MSVC" SET tools_MSVC_Path=!msVS_Path!\VC\Tools\MSVC
)

IF NOT EXIST !msVS_Path! CALL:error 1 "Visual Studio 2017 is not installed"

for /f %%i in ('dir /b %tools_MSVC_Path%') do set tools_MSVC_Version=%%i

CALL:print %debug% "Visual Studio path is !msVS_Path!"
CALL:print %debug% "Visual Studio 2017 Tools MSVC Version is !tools_MSVC_Version!"

GOTO:EOF

:setCompilerOption
CALL:print %trace% "Determining compiler options ..."
REG Query "HKLM\Hardware\Description\System\CentralProcessor\0" | FIND /i "x86" > NUL && SET HOSTCPU=x86 || SET HOSTCPU=x64

CALL:print %trace% "Host CPU architecture is %HOSTCPU%"

IF /I %HOSTCPU% == x86 (
	SET x86BuildCompilerOption=x86
	SET x64BuildCompilerOption=x86_amd64
	SET armBuildCompilerOption=x86_arm
	
	SET x86Win32BuildCompilerOption=x86
  SET x64Win32BuildCompilerOption=x86_amd64
)

IF /I "%~1"=="winuwp" (
  IF /I "%~2"=="x86" (
    SET currentBuildCompilerOption=%x86BuildCompilerOption%
  )
  IF /I "%~2"=="x64" (
    SET currentBuildCompilerOption=%x64BuildCompilerOption%
  )
  IF /I "%~2"=="arm" (
    SET currentBuildCompilerOption=%armBuildCompilerOption%
  )
)

IF /I "%~1"=="win32" (
  IF /I "%~2"=="x86" (
    SET currentBuildCompilerOption=%x86Win32BuildCompilerOption%
  )
  IF /I "%~2"=="x64" (
    SET currentBuildCompilerOption=%x64Win32BuildCompilerOption%
  )
)

CALL:print %trace% "Selected compiler option is %currentBuildCompilerOption%"

GOTO:EOF

:buildNativeLibs

  IF EXIST !baseBuildPath! (
    PUSHD !baseBuildPath!
    SET ninjaPath=..\..\..\..\..\webrtc\xplatform\depot_tools\ninja
    SET outputPath=win_x64_!CONFIGURATION!

    IF /I "%currentPlatform%"=="winuwp" (
      SET outputPath=winuwp_!CPU!_!CONFIGURATION!
    )
    IF /I "%currentPlatform%"=="win32" (
      SET outputPath=win_!CPU!_!CONFIGURATION!
    )
    
    CD !outputPath!
    IF ERRORLEVEL 1 CALL:error 1 "!outputPath! folder doesn't exist"
    
    CALL:print %warning% "Building %SOFTWARE_TARGET% native libs"
    !ninjaPath! %SOFTWARE_TARGET%
    IF ERRORLEVEL 1 CALL:error 1 "Building %SOFTWARE_TARGET% in %CD% has failed"s

    SET buildJsonCppTarget=0
    IF /I "%SOFTWARE_TARGET%"=="webrtc" SET buildJsonCppTarget=1

    REM This should be removed later when do not have to target ORTC to build WebRTC generated wrappers
    IF /I "%SOFTWARE_TARGET%"=="ortc" SET buildJsonCppTarget=1
    
    IF !buildJsonCppTarget! EQU 1 (
      CALL:print %warning% "Building webrtc/rtc_base:rtc_json native lib"
      !ninjaPath! third_party/jsoncpp:jsoncpp
      !ninjaPath! rtc_base:rtc_json    
      IF ERRORLEVEL 1 CALL:error 1 "Building webrtc/rtc_base:rtc_json in %CD% has failed"
    )
    
    IF NOT "%SOFTWARE_PLATFORM%"=="webrtc/examples:peerconnection_server" CALL:combineLibs !outputPath!
    CALL:copyExes !outputPath!
    POPD
  )

GOTO:EOF

:makeOutputLinks
PUSHD !libsSourcePath!
echo *******************************************
echo %CD%
echo %libsSourcePath%

IF EXIST %libsSourcePath%obj\third_party\ortc (
    CALL:makeDirectory ..\..\..\..\..\ortc\windows\projects\msvc\Org.Ortc.Uwp\obj
    CALL:makeLink . ..\..\..\..\..\ortc\windows\projects\msvc\Org.Ortc.Uwp\obj\!outputPath! %libsSourcePath%obj\third_party\ortc\ortclib
) ELSE (
    echo ORTC output paths were not found.
)
POPD
GOTO:EOF

:build

IF EXIST %msVS_Path% (
	CALL %msVS_Path%\VC\Auxiliary\Build\vcvarsall.bat %currentbuildCompilerOption%
	IF ERRORLEVEL 1 CALL:error 1 "Could not setup compiler for %PLATFORM% %CPU%"
	
  rem	MSBuild %SOLUTIONPATH% /property:Configuration=%CONFIGURATION% /property:Platform=%CPU% /t:Build /nodeReuse:False
	MSBuild %SOLUTIONPATH% /property:Configuration=GN /property:Platform=%CPU% /t:Build /nodeReuse:False
	IF ERRORLEVEL 1 CALL:error 1 "Building WebRTC projects for %PLATFORM% %CPU% has failed"
) ELSE (
	CALL:error 1 "Could not compile because proper version of Visual Studio is not found"
)
GOTO:EOF

:strlen
(
    SETLOCAL EnableDelayedExpansion
    SET s=%~2
    SET "len=0"
    FOR %%P IN (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) DO (
        IF "!s:~%%P,1!" NEQ "" ( 
            SET /a "len+=%%P"
            SET "s=!s:~%%P!"
        )
    )
)
( 
    ENDLOCAL
    SET "%~1=%len%"
    EXIT /b
)
GOTO:EOF

:copyExes
CALL:setPaths %~dp1

IF /I "%currentPlatform%"=="winuwp" (
  SET destinationExes=%~dp0\..\output\winuwp_!CPU!_!CONFIGURATION!
)
IF /I "%currentPlatform%"=="win32" (
  SET destinationExes=%~dp0\..\output\win_!CPU!_!CONFIGURATION!
)

IF NOT EXIST %destinationExes% (
  CALL:makeDirectory %destinationExes%
  IF ERRORLEVEL 1 CALL:error 1 "Could not make a directory %destinationExes%"
)

echo COPY %libsSourcePath%\*.exe %destinationExes%\*.exe /Y
COPY %libsSourcePath%\*.exe %destinationExes%\*.exe /Y >NUL

echo COPY %libsSourcePath%\*.pdb %destinationExes%\*.pdb /Y
COPY %libsSourcePath%\*.pdb %destinationExes%\*.pdb /Y >NUL

echo COPY %libsSourcePath%\*.dll %destinationExes%\*.dll /Y
COPY %libsSourcePath%\*.dll %destinationExes%\*.dll /Y >NUL

GOTO:EOF

:combineLibs
CALL:print %debug% "Combining object files into library."

CALL:setPaths %~dp1

CALL %msVS_Path%\VC\Auxiliary\Build\vcvarsall.bat %currentbuildCompilerOption%
IF ERRORLEVEL 1 CALL:error 1 "Could not setup compiler for %PLATFORM% %CPU%"

IF NOT EXIST %destinationPath% (
	CALL:makeDirectory %destinationPath%
	IF ERRORLEVEL 1 CALL:error 1 "Could not make a directory %destinationPath%"
)

SET webRtcLibs=
SET counter=0
FOR /f %%A IN ('forfiles -p %libsSourcePath%obj /s /m *.obj /c "CMD /c ECHO @relpath"') DO ( 
    SET temp=%%~A
    IF "!temp!"=="!temp:ortclib\=!" (
        SET webRtcLibs=!webRtcLibs! %%~A 
        CALL:print %trace%  !webRtcLibs!
        call :strlen result "!webRtcLibs!"
        if !result! lss 7000 echo counter je !counter!
        if !result! gtr 7000 (
            PUSHD %libsSourcePath%obj
            IF NOT "!webRtcLibs!"=="" %msVS_Path%\VC\Tools\MSVC\%tools_MSVC_Version%\bin\Hostx64\!linkPlatform!\lib.exe /IGNORE:4264,4221,4006 /OUT:%destinationPath%webrtc!counter!.lib !webRtcLibs!
            IF ERRORLEVEL 1 CALL:error 1 "Failed combining libs"
            SET /A counter = counter + 1
            CALL:print %trace% "Curernt library counter is !counter!"
            POPD
            SET webRtcLibs=
        )
     ) ELSE (
        CALL:print %debug% "Object file !temp! is ignored"
     )
)


SET /A counter = counter + 1

FOR /f %%A IN ('forfiles -p %libsSourcePath%obj /s /m *.o /c "CMD /c ECHO @relpath"') DO ( SET webRtcLibs=!webRtcLibs! %%~A )
PUSHD %libsSourcePath%obj

IF NOT "!webRtcLibs!"=="" %msVS_Path%\VC\Tools\MSVC\%tools_MSVC_Version%\bin\Hostx64\!linkPlatform!\lib.exe /IGNORE:4264,4221,4006 /OUT:%destinationPath%webrtc!counter!.lib !webRtcLibs!
IF ERRORLEVEL 1 CALL:error 1 "Failed combining libs"
POPD

PUSHD %libsSourcePath%obj
IF NOT "!webRtcLibs!"=="" %msVS_Path%\VC\Tools\MSVC\%tools_MSVC_Version%\bin\Hostx64\!linkPlatform!\lib.exe /IGNORE:4264,4221,4006 /OUT:%destinationPath%webrtc!counter!.lib !webRtcLibs!
IF ERRORLEVEL 1 CALL:error 1 "Failed combining libs"
POPD
            
SET webRtcLibs=
FOR /f %%A IN ('forfiles -p !destinationPath! /s /m *.lib /c "CMD /c ECHO @relpath"') DO ( SET temp=%%~A && IF "!temp!"=="!temp:protobuf_full_do_not_use=!" SET webRtcLibs=!webRtcLibs! %%~A )

PUSHD !destinationPath!
CALL:print %debug% "Merging libraries from !webRtcLibs!"
IF NOT "!webRtcLibs!"=="" %msVS_Path%\VC\Tools\MSVC\%tools_MSVC_Version%\bin\Hostx64\!linkPlatform!\lib.exe /IGNORE:4264,4221,4006 /OUT:webrtc.lib !webRtcLibs!
IF ERRORLEVEL 1 CALL:error 1 "Failed combining libs"
POPD
PUSHD %libsSourcePath%obj
IF EXIST *.dll (
	CALL:print %debug% "Copying dlls from %libsSourcePath%obj to %destinationPath%"
	FOR /f %%A IN ('forfiles -p %libsSourcePath%obj /s /m *.dll /c "CMD /c ECHO @relpath"') DO ( COPY %%~A %destinationPath% >NUL )
)

CALL:print %debug% "Copying pdbs from %libsSourcePath%obj to %destinationPath%"

FOR /f %%A IN ('forfiles -p %libsSourcePath%obj /s /m *.pdb /c "CMD /c ECHO @relpath"') DO ( SET temp=%%~A && IF "!temp!"=="!temp:protobuf_full_do_not_use=!" COPY %%~A %destinationPath% >NUL )

IF ERRORLEVEL 1 CALL:error 0 "Failed copying pdb files"
POPD
GOTO:EOF

:appendLibPath
if "%~1"=="%~1:protobuf_lite.dll=%" SET webRtcLibs=!webRtcLibs! %~1
GOTO:EOF

:moveLibs

IF NOT EXIST %libsSourceBackupPath%NUL (
	CALL:makeDirectory %libsSourceBackupPath%
	CALL:print %trace% "Created folder %libsSourceBackupPath%"
) ELSE (
	IF EXIST %libsSourceBackupPath%%CONFIGURATION%\NUL RD /S /Q %libsSourceBackupPath%%CONFIGURATION%
)


CALL:print %debug% "Copying %libsSourcePath% to %libsSourceBackupPath%"
COPY %libsSourcePath% %libsSourceBackupPath%
if ERRORLEVEL 1 CALL:error 0 "Failed copying %libsSourcePath% to %libsSourceBackupPath%"

GOTO:EOF

:setPaths
SET basePath=%1
SET libsSourcePath=%basePath%

SET libsSourceBackupPath=%basePath%..\..\WEBRTC_BACKUP_BUILD\%SOFTWARE_TARGET%\%CONFIGURATION%\%currentPlatform%_%linkCpu%\

CALL:print %debug% "Source path is "%basePath%""

SET destinationPath=%libsSourcePath%..\..\WEBRTC_BUILD\%SOFTWARE_TARGET%\%CONFIGURATION%\%currentPlatform%_%linkCpu%\

CALL:print %debug% "Destination path is %destinationPath%"
GOTO :EOF

:makeDirectory
IF NOT EXIST %~1\NUL (
	MKDIR %~1
	CALL:print %trace% "Created folder %~1"
) ELSE (
	CALL:print %trace% "%~1 folder already exists"
)
GOTO:EOF

:makeLink
IF NOT EXIST %~1\NUL CALL:error 1 "%folderStructureError:"=% %~1 does not exist!"

PUSHD %~1
IF EXIST .\%~2\NUL GOTO:alreadyexists
IF NOT EXIST %~3\NUL CALL:error 1 "%folderStructureError:"=% %~3 does not exist!"

CALL:print %trace% In path "%~1" creating symbolic link for "%~2" to "%~3"

IF %logLevel% GEQ %trace% (
	MKLINK /J %~2 %~3
) ELSE (
	MKLINK /J %~2 %~3  >NUL
)

IF %ERRORLEVEL% NEQ 0 CALL:ERROR 1 "COULD NOT CREATE SYMBOLIC LINK TO %~2 FROM %~3"

:alreadyexists
CALL:print %trace% "Path "%~2" already exists"
POPD

REM Print logger message. First argument is log level, and second one is the message
:print

SET logType=%1
SET logMessage=%~2

IF %logLevel% GEQ  %logType% (
	IF %logType%==0 ECHO [91m%logMessage%[0m
	IF %logType%==1 ECHO [92m%logMessage%[0m
	IF %logType%==2 ECHO [93m%logMessage%[0m
	IF %logType%==3 ECHO %logMessage%
	IF %logType%==4 ECHO %logMessage%
)

GOTO:EOF

REM Print the error message and terminate further execution if error is critical.Firt argument is critical error flag (1 for critical). Second is error message
:error
SET criticalError=%~1
SET errorMessage=%~2

IF %criticalError%==0 (
	ECHO.
	CALL:print %warning% "WARNING: %errorMessage%"
	ECHO.
) ELSE (
	ECHO.
	CALL:print %error% "CRITICAL ERROR: %errorMessage%"
	ECHO.
	ECHO.
	CALL:print %error% "FAILURE: Building WebRtc library has failed!"
	ECHO.
	SET endTime=%time%
	CALL:showTime
	POPD
	::terminate batch execution
	CALL %~dp0\batchTerminator.bat
)
GOTO:EOF

:showTime

SET options="tokens=1-4 delims=:.,"
FOR /f %options% %%a in ("%startTime%") do SET start_h=%%a&SET /a start_m=100%%b %% 100&SET /a start_s=100%%c %% 100&SET /a start_ms=100%%d %% 100
FOR /f %options% %%a in ("%endTime%") do SET end_h=%%a&SET /a end_m=100%%b %% 100&SET /a end_s=100%%c %% 100&SET /a end_ms=100%%d %% 100

SET /a hours=%end_h%-%start_h%
SET /a mins=%end_m%-%start_m%
SET /a secs=%end_s%-%start_s%
SET /a ms=%end_ms%-%start_ms%
IF %ms% lss 0 SET /a secs = %secs% - 1 & SET /a ms = 100%ms%
IF %secs% lss 0 SET /a mins = %mins% - 1 & SET /a secs = 60%secs%
IF %mins% lss 0 SET /a hours = %hours% - 1 & SET /a mins = 60%mins%
IF %hours% lss 0 SET /a hours = 24%hours%

SET /a totalsecs = %hours%*3600 + %mins%*60 + %secs% 

IF 1%ms% lss 100 SET ms=0%ms%
IF %secs% lss 10 SET secs=0%secs%
IF %mins% lss 10 SET mins=0%mins%
IF %hours% lss 10 SET hours=0%hours%

:: mission accomplished
ECHO [93mTotal execution time: %hours%:%mins%:%secs% (%totalsecs%s total)[0m

GOTO:EOF

:done
ECHO.
CALL:print %info% "Success:  WebRtc library is built successfully."
ECHO.
SET endTime=%time%
CALL:showTime
:end
