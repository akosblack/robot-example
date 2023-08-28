@echo off
setlocal

:: Get the current directory
set "curr_dir=%cd%"

:: Construct the new path for the robot file
set "new_path=%curr_dir%\robot.robot"

:: Create the output directory if it doesn't exist
if not exist "%curr_dir%\log" (
    mkdir "%curr_dir%\log"
)

:: Call your Robot Framework command with the new path and desired options
robot --outputdir log --report None  %new_path%

endlocal
