                                                                                                                        @"
######################################                                                                                 
#                                    #####################################################################################
#       Audit-ServiceAccounts        #
#                                    #####################################################################################
######################################
                                                                                                            

                 Written By: 

                 Justin Brazil          


####   OUTLINE  ###########################################################################################################


        * Runs against all servers specified in `$TARGETSERVERS using Invoke-Command

        * Parses running services

        * Returns an array of custom objects to a master output array

        * Formats as HTML, pops up on screen


############################################################################################################################ 
"@    
#TAGS HTML,Report,Services,Account,Accounts,Service Account,Service Accounts,Running


Function Audit-ServiceAccounts {
      <#
      .SYNOPSIS
      Generates a report showing all service accounts by server for all AD objects listed in the specified OU
      .DESCRIPTION
            * Runs against all servers specified in $TARGETSERVERS using Invoke-Command
            * Parses running services
            * Returns an array of custom objects to a master output array
            * Formats as HTML, pops up on screen
      .EXAMPLE
      Audit-ServiceAccounts -TargetOU "OU=Servers,DC=mydomain,DC=local" -OutputPath 'C:\ServiceAccountReport.html"
      .PARAMETER TargetOU
      Specify the OU that contains the computer objects that you will run this script against.
      .PARAMETER OutputPath
      Set the name/path for the HTML output report
      #>

  [CmdletBinding()]
      param
      (
        [string]$TargetOU = "OU=Servers,DC=mydomain,DC=local",
		
        [string]$OutputPath = 'C:\PowerShell\REPORT - Service Account Audit.html'
      )


    ############################                                                                                       
    #                          #
 ####   SET SCRIPT VARIABLES   #####################################################################################
    #                          #
    ############################


$LDAP = Get-ADComputer -Filter * -SearchBase $TargetOU
$TARGET_SERVERS = $LDAP.DNSHostName
$HTML_REPORT = $OutputPath



    ############################                                                                                       
    #                          #
 ####      INVOKE COMMAND      #####################################################################################
    #                          #
    ############################

            ############################
            #       SCRIPTBLOCK        #           
            ############################

$SCRIPTBLOCK = {

    $MEASURE_SERVICES = Get-WmiObject win32_service | Where {$_.Started -eq $TRUE} | Select StartName,Name,Caption,Started,PSComputerName
    $MEASURE_SERVICE_ACCOUNTS = $MEASURE_SERVICES.StartName.ToUpper() | Select -Unique

    $OUTPUT_ARRAY = @()

    ForEach ($SERVICE_ACCOUNT in $MEASURE_SERVICE_ACCOUNTS)
        {
        #CREATES TEMP ARRAY FOR RETURN TO OUTPUT_ARRAY
        $TEMP_OUTPUT_ARRAY = New-Object -TypeName PSObject
        $TEMP_OUTPUT_ARRAY | Add-Member -MemberType NoteProperty -Name "HostName" -Value $env:COMPUTERNAME
        $TEMP_OUTPUT_ARRAY | Add-Member -MemberType NoteProperty -Name "ServiceAccount" -Value $SERVICE_ACCOUNT
 
        #CREATES SUBARRAY CONTAINING ALL SERVICES, ADDS to TEMP_ARRAY
        $TEMP_TEMP_SERVICE_ARRAY = @()

            ForEach ($SERVICE in $MEASURE_SERVICES)     
               {
    
                If ($SERVICE.StartName -like $SERVICE_ACCOUNT)
                    {
                    $TEMP_TEMP_SERVICE_ARRAY += $SERVICE
                    }
               }
 
        $TEMP_OUTPUT_ARRAY | Add-Member -MemberType NoteProperty -Name "ServiceCount" -Value $TEMP_TEMP_SERVICE_ARRAY.Count
        $TEMP_OUTPUT_ARRAY | Add-Member -MemberType NoteProperty -Name "ServiceList" -Value $TEMP_TEMP_SERVICE_ARRAY
        $OUTPUT_ARRAY += $TEMP_OUTPUT_ARRAY

        }
    $OUTPUT_ARRAY

}  #/Scriptblock

            ############################
            #    INVOKE SCRIPTBLOCK    #           
            ############################

$OUTPUT_INVOKED = Invoke-Command -ComputerName $TARGET_SERVERS -ScriptBlock $SCRIPTBLOCK | Select Hostname,ServiceAccount,ServiceCount,ServiceList,ServiceListString 

    ############################                                                                                       
    #                   .       #
 ####       HTML REPORT        #####################################################################################
    #                          #
    ############################

#GENERATE HTML TABLE 0
$OUTPUT_HTML_TABLE_0 = ($OUTPUT_INVOKED.ServiceList) | Select StartName -Unique|ConvertTo-Html -PreContent "<H2>SERVICE ACCOUNTS AT-A-GLANCE.</H2>" -Fragment

#GENERATE HTML TABLE 1
$OUTPUT_HTML_TABLE_1 = $OUTPUT_INVOKED | Select HostName,ServiceAccount,ServiceCount | Sort Hostname |ConvertTo-Html -PreContent "<H2>SERVICE ACCOUNTS AT-A-GLANCE.</H2>" -Fragment

#GENERATE HTML TABLE 2
$OUTPUT_HTML_TABLE_2 = ForEach ($SERVER in $OUTPUT_INVOKED)
    {
    Write-Output $SERVER.ServiceList | Select Name,Caption,PSComputerName,Started | ConvertTo-HTML -PreContent "<H2>$($SERVER.Hostname) - $($SERVER.ServiceAccount) - Running Services</H2>" -Fragment 
    }

#GENERATE HTML HEADERS/TITLES
$OUTPUT_HTML_TABLE_0_TITLE = "<H1>============UNIQUE ACCOUNTS ON ALL SERVERS : $(Get-Date)============</H1>"
$OUTPUT_HTML_TABLE_1_TITLE = "<H1>============SERVICE ACCOUNTS PER SERVER : $(Get-Date)============</H1>"
$OUTPUT_HTML_TABLE_2_TITLE = "<H1>============RUNNING SERVICES AND ACCOUNTS PER SERVER============</H1>"

#GENERATE CSS
$OUTPUT_HTML_CSS = "<style>"
$OUTPUT_HTML_CSS = $OUTPUT_HTML_CSS + "BODY{background-color:#CEE3F6;}"
$OUTPUT_HTML_CSS = $OUTPUT_HTML_CSS + "TABLE{border-width: 3px;border-style: solid;border-color: black;border-collapse: collapse;}"
$OUTPUT_HTML_CSS = $OUTPUT_HTML_CSS + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#819FF7}"
$OUTPUT_HTML_CSS = $OUTPUT_HTML_CSS + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#FFFFFF}"
$OUTPUT_HTML_CSS = $OUTPUT_HTML_CSS + "</style>"

#COMBINE HTML ELEMENTS, DISPLAY REPORT
ConvertTo-HTML -Body "$OUTPUT_HTML_TABLE_0_TITLE $OUTPUT_HTML_TABLE_0 $OUTPUT_HTML_TABLE_1_TITLE $OUTPUT_HTML_TABLE_1 $OUTPUT_HTML_TABLE_2_TITLE $OUTPUT_HTML_TABLE_2" -Title "SERVICES by SERVICE ACCOUNT" -Head $OUTPUT_HTML_CSS | Out-File $HTML_REPORT
&$HTML_REPORT

}