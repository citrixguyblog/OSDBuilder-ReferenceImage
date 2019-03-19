#==========================================================================
#
# Automating Reference Image with OSDBuilder
#
# AUTHOR: Julian Mooren (https://citrixguyblog.com)
# DATE  : 03.18.2019
#
# PowerShell Template by Dennis Span (http://dennisspan.com)
#
#==========================================================================


# define Error handling
# note: do not change these values
$global:ErrorActionPreference = "Stop"
if($verbose){ $global:VerbosePreference = "Continue" }


# FUNCTION DS_WriteLog
#==========================================================================
Function DS_WriteLog {
    <#
        .SYNOPSIS
        Write text to this script's log file
        .DESCRIPTION
        Write text to this script's log file
        .PARAMETER InformationType
        This parameter contains the information type prefix. Possible prefixes and information types are:
            I = Information
            S = Success
            W = Warning
            E = Error
            - = No status
        .PARAMETER Text
        This parameter contains the text (the line) you want to write to the log file. If text in the parameter is omitted, an empty line is written.
        .PARAMETER LogFile
        This parameter contains the full path, the file name and file extension to the log file (e.g. C:\Logs\MyApps\MylogFile.log)
        .EXAMPLE
        DS_WriteLog -$InformationType "I" -Text "Copy files to C:\Temp" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing information to the log file
        .Example
        DS_WriteLog -$InformationType "E" -Text "An error occurred trying to copy files to C:\Temp (error: $($Error[0]))" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing error information to the log file
        .Example
        DS_WriteLog -$InformationType "-" -Text "" -LogFile "C:\Logs\MylogFile.log"
        Writes an empty line to the log file
    #>
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
        [Parameter(Mandatory=$true, Position = 2)][AllowEmptyString()][String]$LogFile
    )
 
    begin {
    }
 
    process {
     $DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
 
        if ( $Text -eq "" ) {
            Add-Content $LogFile -value ("") # Write an empty line
        } Else {
         Add-Content $LogFile -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }
    }
 
    end {
    }
}
#==========================================================================

################
# Main section #
################

# Custom variables 
$BaseLogDir = "C:\Logs"                               
$PackageName = "OSDBuilder"

# OSDBuilder variables 
$OSDBuilderDir = "C:\OSDBuilder"    
$TaskName = "Build-031819"           

#MDT variables
$MDTShare = "C:\Hydration"


# Global variables
$StartDir = $PSScriptRoot # the directory path of the script currently being executed
$LogDir = (Join-Path $BaseLogDir $PackageName).Replace(" ","_")
$LogFileName = "$PackageName.log"
$LogFile = Join-path $LogDir $LogFileName


# Create the log directory if it does not exist
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType directory | Out-Null }

# Create new log file (overwrite existing one)
New-Item $LogFile -ItemType "file" -force | Out-Null


# ---------------------------------------------------------------------------------------------------------------------------


DS_WriteLog "I" "START SCRIPT - $Installationtype $PackageName" $LogFile
DS_WriteLog "-" "" $LogFile


#################################################
# Update OSDBuilder PoweShell Module            #
#################################################

DS_WriteLog "I" "Looking for installed OSDBuilder Module..." $LogFile


try {
      $Version =  Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\OSDBuilder" | Sort-Object LastAccessTime -Descending | Select-Object -First 1
      DS_WriteLog "S" "OSDBuilder Module is installed - Version: $Version" $LogFile
     } catch {
              DS_WriteLog "E" "An error occurred while looking for the OSDBuilder PowerShell Module (error: $($error[0]))" $LogFile
              Exit 1
             }



DS_WriteLog "I" "Checking for newer OSDBuilder Module in the PowerShell Galery..." $LogFile


try {
      $NewBuild = Find-Module -Name OSDBuilder
      DS_WriteLog "S" "The newest OSDBuilder Module is Version: $($NewBuild.Version)" $LogFile
     } catch {
              DS_WriteLog "E" "An error occurred while looking for the OSDBuilder PowerShell Module (error: $($error[0]))" $LogFile
              Exit 1
             }



 if($Version.Name -lt  $NewBuild.Version)
  {
  try {
         DS_WriteLog "I" "Update is available.Update in progress...." $LogFile
         OSDBuilder -Update
         DS_WriteLog "S" "OSDBuilder Update completed succesfully to Version: $($NewBuild.Version)" $LogFile
       
     } catch {
              DS_WriteLog "E" "An error occurred while updating the OSDBuilder Module (error: $($error[0]))" $LogFile
              Exit 1
             }
  }


else {DS_WriteLog "I" "Newest OSDBuilder is already installed." $LogFile}


DS_WriteLog "I" "Trying to Import the OSDBuilder Module..." $LogFile


try {
        Import-Module -Name OSDBuilder -Force
        DS_WriteLog "S" "Module got imported" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while importing the OSDBuilder Module (error: $($error[0]))" $LogFile
              Exit 1
             }


DS_WriteLog "-" "" $LogFile


#################################################
# Update  of the OS-Media                       #
#################################################


DS_WriteLog "I" "Starting Update of OS-Media - Task $TaskName" $LogFile


try {
        $StartDTM = (Get-Date)
        New-OSBuild -ByTaskName $TaskName -Download -Execute -SkipComponentCleanup  
        $EndDTM = (Get-Date)  
        DS_WriteLog "S" "OS-Media Creation for Task $TaskName completed succesfully" $LogFile
        DS_WriteLog "I" "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while creating the OS-Media (error: $($error[0]))" $LogFile
              Exit 1
             }


#################################################
# Import the OS-Media to the MDT-Share          #
#################################################

DS_WriteLog "I" "Searching for OS-Build Source Directory" $LogFile

try {
        $OSBuildSource = Get-ChildItem -Path "$OSDBuilderDir\OSBuilds" | Sort-Object LastAccessTime -Descending | Select-Object -First 1
        DS_WriteLog "S" "Found the latest OS-Build directory - $($OSBuildSource.FullName) " $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while searching the latest OS-Build directory (error: $($error[0]))" $LogFile
              Exit 1
             }


DS_WriteLog "I" "Importing Microsoft Deployment Toolkit PowerShell Module" $LogFile

try {
        Import-Module "C:\Program Files\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1"
        DS_WriteLog "S" "MDT PS Module got imported successfully" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while importing the MDT PowerShell Module (error: $($error[0]))" $LogFile
              Exit 1
             }


DS_WriteLog "I" "Adding MDT Peristent Drive" $LogFile


try {
        New-PSDrive -Name "DS001" -PSProvider "MDTProvider" –Root $MDTShare -Description "MDT Deployment Share" 
        DS_WriteLog "S" "Created MDT Persistent Drive" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while creating the MDT Persitent Drive (error: $($error[0]))" $LogFile
              Exit 1
             }


DS_WriteLog "I" "Importing OS-Build to MDT" $LogFile

try {
        $date = Get-Date -Format MMddyyy
        New-Item -Path "DS001:\Operating Systems\OSDBuilder-$date" -ItemType "Directory"
        Import-MDTOperatingSystem -Path "DS001:\Operating Systems\OSDBuilder-$date" -SourcePath "$($OSBuildSource.FullName)\OS" -DestinationFolder "OSDBuilder-$date"
        DS_WriteLog "S" "Imported latest OS-Build" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while importing the OS-Build (error: $($error[0]))" $LogFile
              Exit 1
             }



try {
        Remove-PSDrive -Name "DS001"
        DS_WriteLog "S" "Removed the MDT Persistent Drive" $LogFile
     }  catch {
              DS_WriteLog "E" "An error occurred while removing the MDT Persistent Drive (error: $($error[0]))" $LogFile
              Exit 1
             }




# ---------------------------------------------------------------------------------------------------------------------------


DS_WriteLog "-" "" $LogFile
DS_WriteLog "I" "End of script" $LogFile
