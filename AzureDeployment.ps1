$resourceGroupName = "AzureDeployment"
$prefix = "sentia"
$ipPrefix = "172.16.0.0/12"
$ipPrefixSplit = $ipPrefix.split(".") 
$newTags = @{ 
    "Environment"="Test"
    "Company"="Sentia"
}
[array]$resourceProviders = "Microsoft.Compute","Microsoft.Network","Microsoft.Storage"
$locationName = "West Europe"
$numberOfSubnets = "3"
$policyName = "allowed-resourcetypes"
$policyDisplayName = "Allowed resource types"
$policyDescription = "This policy enables you to specify the resource types that your organization can deploy." 
$policy = 'https://raw.githubusercontent.com/Azure/azure-policy/master/samples/built-in-policy/allowed-resourcetypes/azurepolicy.rules.json' 
$policyParameter = 'https://raw.githubusercontent.com/Azure/azure-policy/master/samples/built-in-policy/allowed-resourcetypes/azurepolicy.parameters.json'
$storageEncryption = "Blob,File"


try{
    #Starting importing all the necessary modules
    $here = (Split-Path -Parent $MyInvocation.MyCommand.Path)
    Import-Module "$here\AzureGeneralFunctions.psm1"
    Import-Module AzureRM

    #Login automaticly into your Azure subscription
    Select-RMSubscription -SubscriptionID $subscriptionID  -Username $username -Password $password -ErrorAction Stop

    #Getting the right location format
    $location = (Get-AzureRmLocation | Where-Object{$_.DisplayName -eq $locationName}).location
   
    #Checking if there are . If not, then create the new resource group
    $allResourceGroups = Get-AzureRmResourceGroup
    $resourceGroupPrefix = $prefix + "resourcegroup"
    $checkResourceGroups = $allResourceGroups.ResourceGroupName | Where-Object{ $_ -match $resourceGroupPrefix}
    if($checkResourceGroups){
        [int]$latestGroup = ($checkResourceGroups -replace '\D+(\d+)','$1'  | Sort-Object @{e={$_-as [int]}}) | Select-Object -Last 1
        $resourceGroupName = $resourceGroupPrefix + ($latestGroup + 1)
    }else{
         $resourceGroupName = $resourceGroupPrefix + "0"
    }
    $newResourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

    #Creating new storage account. The name of the storage account needs to be lower case
    New-AzureRmStorageAccount -Name ($prefix + $resourceGroupName).tolower() -Location $location -ResourceGroupName $resourceGroupName -SkuName Standard_LRS -EnableEncryptionService $storageEncryption

    #Creating new virtualnetwork and the specified amount of subnets
    $newVirtualNetwork = New-AzureRmVirtualNetwork -AddressPrefix $ipPrefix -Location $location -Name ($prefix + "virtualnetwork") -ResourceGroupName $resourceGroupName
    $i = 0
    while($i -lt $numberOfSubnets){
        $subnetAddress = ($ipPrefixSplit[0] + "." + $ipPrefixSplit[1] + "." + $i + "." + $ipPrefixSplit[3].split("/")[0] + "/24") 
        $subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig -Name ($prefix + $i) -AddressPrefix $subnetAddress  -VirtualNetwork $newVirtualNetwork
        $i++
        $setSubnetToVirtualNetwork = $newVirtualNetwork | Set-AzureRmVirtualNetwork
    }

    #Adding tags to the new created resource group
    $newTags | Foreach-object{
        $tags += $_
    }
    $newResourceGroup | Set-AzureRmResourceGroup -Tag $tags

    #Getting all the resources which has the provider(s) specified in the $resourceProviders
    $resourceProviders | ForEach-Object{
        $provider = $_
        $filteredResourceTypes = (Get-AzureRmResourceProvider -ProviderNamespace $_).ResourceTypes
        $filteredResourceTypes | ForEach-Object{
            $resources += ($provider + "/" + $_.ResourceTypeName)
        }
    }

    
    $allPolicies = Get-AzureRmPolicyDefinition
    if($allPolicies.Name -contains $PolicyName){
        #Found a policy with the same name, using this policy
        $policyDefinition = $allPolicies | Where-Object{$_.Name -eq $PolicyName}
    }else{
        #Creating new policy definition, which can created with a policy file and a parameter file
        $policyDefinition = New-AzureRmPolicyDefinition -Name $PolicyName -DisplayName $PolicyDisplayName -description $PolicyDescription -Policy $policy -Parameter $policyParameter -Mode All
    }

    #Assign the  policy to the new resource group
    $assignment = New-AzureRMPolicyAssignment -Name ($prefix + "Policy") -Scope $newResourceGroup.ResourceId -listOfResourceTypesAllowed ($resources) -PolicyDefinition $policyDefinition 
}catch{
    Write-Error $error[0]
}