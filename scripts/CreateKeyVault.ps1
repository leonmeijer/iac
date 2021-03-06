param(
    [Parameter(Mandatory = $true, Position = 1)]
    [String]$ResourceGroupName,

    [Parameter(Mandatory = $true, Position = 2)]
    [String]$KeyVaultName
)

$azcontext = Get-AzureRmContext
if ([string]::IsNullOrEmpty($azcontext.Account)) {
    throw "User not logged into Azure."   
} 

$rg = Get-AzureRmResourceGroup -Name $ResourceGroupName

# Create a new AD application
$identifierUri = [string]::Format("http://localhost:8080/{0}", [Guid]::NewGuid().ToString("N"))
$defaultHomePage = 'http://contoso.com'
$now = [System.DateTime]::Now
$oneYearFromNow = $now.AddYears(1)
$aadClientSecret =  [System.Convert]::ToBase64String($([guid]::NewGuid()).ToByteArray())
$aadClientPassword = ConvertTo-SecureString -String $aadClientSecret -AsPlainText -Force
$aadAppName = $KeyVaultName + "aadapp"

$ADApp = New-AzureRmADApplication -DisplayName $aadAppName -HomePage $defaultHomePage -IdentifierUris $identifierUri  -StartDate $now -EndDate $oneYearFromNow -Password $aadClientPassword
$servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $ADApp.ApplicationId
$SvcPrincipals = (Get-AzureRmADServicePrincipal -SearchString $aadAppName)
if (-not $SvcPrincipals) {
    # AAD app wasn't created 
    Write-Error "Failed to create AAD app $aadAppName. Please log-in to Azure using Login-AzureRmAccount  and try again";
    return;
}
$aadClientID = $servicePrincipal.ApplicationId;

$kv = New-AzureRmKeyVault -VaultName $KeyVaultName -Location $rg.Location -ResourceGroupName $ResourceGroupName
$kek = Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name "DiskKeyEncryptionKey" -Destination Software

# Specify privileges to the vault for the AAD application - https://msdn.microsoft.com/en-us/library/mt603625.aspx
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -ServicePrincipalName $aadClientID -PermissionsToKeys wrapKey -PermissionsToSecrets set;
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName -EnabledForDiskEncryption -EnabledForDeployment -EnabledForTemplateDeployment
    
$keyVaultInfo = @{
    "AADClientID" = $aadClientID
    "AADClientSecret" = $aadClientSecret
    "KeyVaultURL" = $kv.VaultUri
    "KeyVaultResourceId" = $kv.ResourceId
    "KeyEncryptionKeyURL" = $kek.Key.Kid
}   

return $keyVaultInfo
