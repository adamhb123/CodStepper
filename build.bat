@echo off
:move
	echo Moving %~1 to %~2
	move %~1 %~2
	echo Moved %~1 to %~2
	goto:eof

:removeDir
	echo Deleting %~1
	rmdir /s /q %~1
	echo Deleted %~1
	goto:eof

:run
	set DIR=%~dp0
    echo Administrative permissions required. Detecting permissions...
    net session >nul 2>&1
    if %errorLevel% == 0 (
        echo Success: Administrative permissions confirmed.
		pyinstaller --onefile "%DIR%wait.py"
		call:removeDir "%DIR%build"
		call:removeDir "%DIR%__pycache__"
		call:move "%DIR%dist\wait.exe" , "%DIR%wait.exe"
		call:removeDir "%DIR%dist"
    ) else (
        echo Current permissions inadequate, please run as Administrator!
        pause
    )
    goto:eof

goto:run
