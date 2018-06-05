function Select-RMSubscription{
    [CmdletBinding()]
    param(        
        [parameter(Mandatory=$true)] 
        [String] 
        $SubscriptionID,

        [parameter(Mandatory=$true)] 
        [String] 
        $Username,

        [parameter(Mandatory=$true)] 
        [String] 
        $Password
    )
    $functionName = $MyInvocation.MyCommand

	Write-Output ("{0:s} - Start executing '{1}'" -f (get-date), $functionName)

	$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
	$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $securePassword
	        
    $account = Add-AzureRMAccount -Credential $credential
            
    if($account)
    {
        $subscription = Select-AzureRmSubscription -SubscriptionID $SubscriptionID -ErrorAction Stop

        if($subscription)
        {
                 
            Write-Output ("{0:s} - Found subscription with id: '{1}' and name: '{2}'" -f (get-date), $subscription.Subscription.SubscriptionId, $subscription.Subscription.Name)
        }
    }    
}