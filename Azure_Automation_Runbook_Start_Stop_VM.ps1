#Contributor Role Explicitly Provided for the Default Service Principal Created for this Automation Account to Input Subscription ID's

#Webhook Parameters Definition from External POST Request

Param(
		[Parameter (Mandatory= $false)]
	    [object] $WebhookData
	)

#Parameter Initialization Block Post Request Body from External API Call

if ($WebhookData)
{

    Write-Output ("Webhook Invoke Succesfull.External Request IS "+$PSPrivateMetadata.JobId);

    $INP_PARAM=$WebhookData

    # Get The POST Request Body From External Call

    $VAR_INP_VM_NAME_TMP=($INP_PARAM.RequestBody)|ConvertFrom-Json
    $JSON_ARR=($VAR_INP_VM_NAME_TMP.Virtual_Machine)
       
}
else
{
    Write-Output ("Webhook Invoke Failed. Request Is Missing. External Request IS ["+$WebhookData+"]")
    Write-Output ("Powershell Will Exit")
    Exit
}

#Credentials and Initial Variable Assignments

$Azure_Run_As_Connection=Get-AutomationConnection -Name 'AzureRunAsConnection';
 
$ApplicationId=$Azure_Run_As_Connection.ApplicationId; 
$TenantId=$Azure_Run_As_Connection.TenantId; 
$CertificateThumbprintID=$Azure_Run_As_Connection.CertificateThumbprint;

#################### Get Automation Variable Credentials #############################################

$ERR=""
$SQL_Credential=Get-AutomationPSCredential -Name 'VM_Credentials'

$Error.Clear()
if ($SQL_Credential -eq $null) 
{ 
    Write-Output ("Get SQL Credentials Failed. Error Details:- "+$Error[0])
    Write-Output ("Powershell Will Exit")
    Exit
}  
else
{
    $Sql_Username = $SQL_Credential.UserName 
    $Sql_Password_TMP = $SQL_Credential.GetNetworkCredential().Password
    $Sql_Password = $Sql_Password_TMP

    $Sql_Server=Get-AutomationVariable -Name 'VAR_VM_Server_IP'
    $Sql_DB=Get-AutomationVariable -Name 'VAR_VM_Server_DB'
    $Sql_Port=Get-AutomationVariable -Name 'VAR_VM_Server_Port'

    $Sql_Conn=New-Object System.Data.SqlClient.SqlConnection
    $Sql_Conn.ConnectionString="Data Source=$Sql_Server;Database=$Sql_DB;User ID=$Sql_Username;Password=$Sql_Password;"

    $Error.Clear()
    $Sql_Conn.Open()
    
    $Error.Clear()
    $Sql_Cmd=new-object system.Data.SqlClient.SqlCommand
    $Sql_Cmd.Connection=$Sql_Conn
    $Sql_Cmd.Transaction=$Sql_Conn.BeginTransaction() 
    
    if ($Error.Count -gt 0)
    {   

        $ERR=$Error[0]-replace "'","''"
        $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Get Automation Variable Credentials','SQL Connection Failed','Failed','{1}')" -f $PSPrivateMetadata.JobId,$ERR
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
		$Sql_Conn.Close()

        Write-Output ("Powershell Will Exit")
        Exit

    }
    else
    {
    
        $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Get Automation Variable Credentials','SQL Connection Succedeed','Success','{1}')" -f $PSPrivateMetadata.JobId, $Error[0]
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
		$Sql_Conn.Close()

    }

    

}


#################### Login / Handshake with Service Principal Block ####################

$ERR=""
$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Login / Handshake with Service Principal','Handshake Started','Started','{1}')" -f $PSPrivateMetadata.JobId, $Error[0]
$Sql_Conn.Open()
$Sql_Cmd.ExecuteNonQuery()
$Sql_Cmd.Transaction.Commit()
$Sql_Conn.Close()

$Error.Clear()
$Connect=Login-AzureRmAccount -ServicePrincipal -TenantId $TenantId -CertificateThumbprint $CertificateThumbprintID -ApplicationId $ApplicationId

if ($Error.Count -gt 0)
{
    $ERR=$Error[0]-replace "'","''"
    $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Login / Handshake with Service Principal','Handshake Failed','Failed','{1}')" -f $PSPrivateMetadata.JobId, $Error[0]
    $Sql_Conn.Open()
    $Sql_Cmd.ExecuteNonQuery()
    $Sql_Cmd.Transaction.Commit()
	$Sql_Conn.Close()

    Write-Output ("Connection To Service Principal Failed For Subscription "+$SubscriptionID+".Error Details:- "+$Error[0]);
    Write-Output ("Powershell Will Exit")

    Exit

}
else
{
    Write-Output ("Connection To Service Principal Succesfull For Subscription "+$SubscriptionID);
    Write-Output $Connect;

    $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Login / Handshake with Service Principal','Handshake Succedeed','Success','{1}')" -f $PSPrivateMetadata.JobId, $Error[0]
    $Sql_Conn.Open()
    $Sql_Cmd.ExecuteNonQuery()
    $Sql_Cmd.Transaction.Commit()
	$Sql_Conn.Close()

}



################## Read The JSON and Loop through Virtual Machines and Perform START/STOP Operations #######################

$VAR_J=0

foreach ($LOOP_JSON_ARR in $JSON_ARR)
{

    Write-Output("#####################################################################################")

    Write-Output($VAR_J.ToString()+" th Instance Of Virtual Machine Operation Is In Progress")
    
    $VAR_INP_VM_NAME=$LOOP_JSON_ARR.INP_Virtual_Machine_Name
    $VAR_INP_RG_NM=$LOOP_JSON_ARR.INP_ResourceGroup
    $VAR_INP_SUBS_ID=$LOOP_JSON_ARR.INP_Subscription_ID

    Write-Output ("INPUT INP_Subscription_ID Is ["+$VAR_INP_SUBS_ID+"]")
    Write-Output ("INPUT INP_ResourceGroup_Name Is ["+$VAR_INP_RG_NM+"]")
    Write-Output ("INPUT INP_Virtual_Machine_Name Is ["+$VAR_INP_VM_NAME+"]")

    Write-Output("#####################################################################################")

    $SubscriptionID=$VAR_INP_SUBS_ID
    $RG_NAME=$VAR_INP_RG_NM
    $VM_Name=$VAR_INP_VM_NAME

    #################### Subscription Set Block ####################
	
	$Error.Clear()
	$ERR=""
	$SUBS_STR="Subscription Set For "+$SubscriptionID+ " Started"
	$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Subscription Set','{1}','Started','{2}')" -f $PSPrivateMetadata.JobId,$SUBS_STR,$ERR
	$Sql_Conn.Open()
	$Sql_Cmd.ExecuteNonQuery()
	$Sql_Cmd.Transaction.Commit()
	$Sql_Conn.Close()

    $Error.Clear()
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID

    if ($Error.Count -gt 0)
    {

		$SUBS_STR="Subscription Set For "+$SubscriptionID+ " Failed"
        $ERR=$Error[0]-replace "'","''"
        $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Subscription Set','{1}','Failed','{2}')" -f $PSPrivateMetadata.JobId,$SUBS_STR,$ERR
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
        $Sql_Conn.Close()
        
        Write-Output ("Failed To Set Azure Subscription To "+$SubscriptionID+".Error Details:- "+$Error[0]);
        Write-Output ("Powershell Will Exit")
        Exit

    }
    else
    {	
		$SUBS_STR="Subscription Set For "+$SubscriptionID+ " Succedeed"
        $Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Subscription Set','{1}','Succedeed','{2}')" -f $PSPrivateMetadata.JobId,$SUBS_STR,$Error[0]
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
		$Sql_Conn.Close()

        Write-Output ("Current Subscription Set To:- "+$SubscriptionID);
		
    }

    #################### Get Azure Virtual Machine Current Preview/Status ####################

	$ERR=""
	$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Get Azure Virtual Machine Current Preview/Status','Get Azure Virtual Machine Current Preview/Status Started','Started','{1}')" -f $PSPrivateMetadata.JobId,$ERR
	$Sql_Conn.Open()
	$Sql_Cmd.ExecuteNonQuery()
	$Sql_Cmd.Transaction.Commit()
	$Sql_Conn.Close()
	
	$Error.Clear()
    $Current_State=Get-AzureRmVM -ResourceGroupName $RG_NAME -Name $VM_Name -Status
	
	
	#Write-Output ("Error IS "+$ERR)
    
    if ($Error.Count -gt 0)
    {
		
        $ERR=$Error[0]-replace "'","''"
		$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Get Azure Virtual Machine Current Preview/Status','Get Azure Virtual Machine Current Preview/Status Failed','Failed','{1}')" -f $PSPrivateMetadata.JobId,$ERR
        #$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID) VALUES('1')"
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
        $Sql_Conn.Close()
		
        Write-Output ("Failed To Get Status Of Azure Virtual Machine "+$VM_Name+".Error Details:- "+$ERR);
        Write-Output ("Powershell Will Exit")
        Exit

    }
	else
	{
		$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Get Azure Virtual Machine Current Preview/Status','Get Azure Virtual Machine Current Preview/Status Succedeed','Success','{1}')" -f $PSPrivateMetadata.JobId,$ERR
        $Sql_Conn.Open()
        $Sql_Cmd.ExecuteNonQuery()
        $Sql_Cmd.Transaction.Commit()
        $Sql_Conn.Close()
		
        Write-Output ("Succesfully Retrieved Status Of Azure Virtual Machine "+$VM_Name+".Error Details:- "+$Error[0]);
        
	}

    #################### Change Virtual Machine State Start->STOP / STOP-> START ####################

    $Error.Clear()
    foreach ($LoopVMStatus in $Current_State.Statuses.DisplayStatus)
    {
        $ERR=""
        Write-Output ("Current Azure Virtual Machine "+$VM_Name+ " Status IS:-  " + $LoopVMStatus);

        
        if ($LoopVMStatus -eq "VM deallocated")
        {
			
			$ERR=""
			$PRE_VM_STAT="Current State Of Virtual Machine "+$VM_Name+" IS "+$LoopVMStatus
			$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Started','{2}')" -f $PSPrivateMetadata.JobId,$PRE_VM_STAT,$ERR
			$Sql_Conn.Open()
			$Sql_Cmd.ExecuteNonQuery()
			$Sql_Cmd.Transaction.Commit()
			$Sql_Conn.Close()
		
            $Error.Clear()
            Start-AzureRmVM -ResourceGroupName $RG_NAME -Name $VM_Name

            if ($Error.Count -gt 0)
            {
				
                $ERR=$Error[0]-replace "'","''"
				$POST_VM_STAT="Failed To Changed The State Of Virtual Machine "+$VM_Name
				$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Failed','{2}')" -f $PSPrivateMetadata.JobId,$POST_VM_STAT,$ERR
				$Sql_Conn.Open()
				$Sql_Cmd.ExecuteNonQuery()
				$Sql_Cmd.Transaction.Commit()
				$Sql_Conn.Close()
				
                Write-Output ("Failed To Start Azure VM Instance "+$VM_Name+".Error Details:- "+$Error[0]);
                Write-Output ("Powershell Will Exit")
                Exit

            }
            else
            {
			
				$Error.Clear()
				$Modified_State=Get-AzureRmVM -ResourceGroupName $RG_NAME -Name $VM_Name -Status
				
				$POST_VM_STAT="Updated State Of Virtual Machine IS "+$VM_Name+" IS [ "+$Modified_State.Statuses.DisplayStatus+" ]"
				$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Succeeded','{2}')" -f $PSPrivateMetadata.JobId,$POST_VM_STAT,$Error[0]
				$Sql_Conn.Open()
				$Sql_Cmd.ExecuteNonQuery()
				$Sql_Cmd.Transaction.Commit()
				$Sql_Conn.Close()
				
                Write-Output ("Succesfully Started Azure VM Instance["+$VM_Name+"]");
				
            }
        }
        elseif ($LoopVMStatus -eq "VM running")
        {
		
			$ERR=""
			$PRE_VM_STAT="Current State Of Virtual Machine "+$VM_Name+" IS "+$LoopVMStatus
			$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Started','{2}')" -f $PSPrivateMetadata.JobId,$PRE_VM_STAT,$ERR
			$Sql_Conn.Open()
			$Sql_Cmd.ExecuteNonQuery()
			$Sql_Cmd.Transaction.Commit()
			$Sql_Conn.Close()
			
            $Error.Clear()
            Stop-AzureRmVM -ResourceGroupName $RG_NAME -Name $VM_Name -Force 

            if ($Error.Count -gt 0)
            {

                $ERR=$Error[0]-replace "'","''"
				$POST_VM_STAT="Failed To Changed The State Of Virtual Machine "+$VM_Name
				$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Failed','{2}')" -f $PSPrivateMetadata.JobId,$POST_VM_STAT,$ERR
				$Sql_Conn.Open()
				$Sql_Cmd.ExecuteNonQuery()
				$Sql_Cmd.Transaction.Commit()
				$Sql_Conn.Close()

                Write-Output ("Failed To Pause Azure VM Instance "+$VM_Name+".Error Details:- "+$Error[0]);
                Write-Output ("Powershell Will Exit")
                Exit

            }
            else
            {
			
				$Error.Clear()
				$Modified_State=Get-AzureRmVM -ResourceGroupName $RG_NAME -Name $VM_Name -Status
				
				$POST_VM_STAT="Updated State Of Virtual Machine IS "+$VM_Name+" IS [ "+$Modified_State.Statuses.DisplayStatus+" ]"
				$Sql_Cmd.CommandText="INSERT INTO [dbo].[POWERSHELL_LOG] (JOB_ID,STEP,Operation,STATUS,DTLS) VALUES('{0}','Change Virtual Machine State','{1}','Succedeed','{2}')" -f $PSPrivateMetadata.JobId,$POST_VM_STAT,$Error[0]
				$Sql_Conn.Open()
				$Sql_Cmd.ExecuteNonQuery()
				$Sql_Cmd.Transaction.Commit()
				$Sql_Conn.Close()
				
                Write-Output ("Succesfully Stopped Azure VM Instance["+$VM_Name+"]");
            }
        }
        else
        {
            continue
        }
    }

    $VAR_J++

}

$Sql_Conn.Close()


