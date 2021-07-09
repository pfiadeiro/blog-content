# sqlServerPassword must be between 8 to 128 characters and include three of the following categories: 
# English uppercase letters, English lowercase letters, numbers and non-alphanumeric characters. 
# It cannot contain all or part of the login name

# Example usage: .\DeployAzureResources.ps1 -SqlServerPassword 'YourVer1S3cur3Passw0rd' -RgName 'rg-name'

[CmdletBinding(DefaultParametersetName='None')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlServerPassword,

        [Parameter(Mandatory = $true)]
        [string]$RgName,

        [Parameter()]
        [string]$Location = "West Europe"
    )

    function CreateResourceGroup($ResourceGroupName) {
        az group create --name $ResourceGroupName --location $Location --output none  
    }


    function CheckResourceGroup {
        Write-Host "Checking if resource group '$RgName' exists..." -ForegroundColor Magenta
        $Rg = az group exists --resource-group $RgName
        if ($Rg -eq "false") {

            Write-Host "Resource group '$RgName' doesn't exist, creating resource group now..." -ForegroundColor Yellow
            CreateResourceGroup -resourceGroupName $RgName

            if (!$?) {
                Write-Host "Resource group creation failed. Please check the error and try again." -ForegroundColor Red
                break  
            }
            else {
                Write-Host "'$RgName' resource group created." -ForegroundColor Green
            }

        }
        else {
            Write-Host "Resource groups '$RgName' already exists." -ForegroundColor Yellow
        }
    }

    function CreateDeployment {
        Write-Host "Starting ARM template deployment" -ForegroundColor Yellow
        $TemplateFile = Join-Path -Path (Get-Location) -ChildPath '\ARMTemplates\azuredeploy.json'
        $TemplateParameters = Join-Path -Path (Get-Location) -ChildPath '\ARMTemplates\azuredeploy.parameters.json'
        $ErrorMessage = $($Result = az deployment group create -g $RgName --template-file $TemplateFile --parameters $TemplateParameters --parameters sqlAdminPassword=$SqlServerPassword --name 'demo-objects') 2>&1

        if ($null -eq $Result) {

            Write-Host "ARM template deployment failed. Please check the details of the error below and try again." -ForegroundColor Red
            Write-Host $ErrorMessage -ForegroundColor Red
            break  

        }
        else {
             Write-Host "ARM template deployment completed successfully" -ForegroundColor Green
        }

    }

    function CreateSQLObjects($Password) {
        Write-Host "Starting creation of SQL Database objects" -ForegroundColor Yellow
        $createScript = Get-Content (Join-Path -Path (Get-Location) -ChildPath '\SQLScripts\CreateTable.sql') -Raw
        $insertScript = Get-Content (Join-Path -Path (Get-Location) -ChildPath '\SQLScripts\InsertRecords.sql') -Raw

        $ServerInstance = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sourceSqlServer.value -o tsv
        $DatabaseName = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sourceDB.value -o tsv
        $Username = az  deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sqlAdmin.value -o tsv

        $params = @{
            'ServerInstance' = $ServerInstance;
            'Database' = $DatabaseName;
            'Username' = $Username;
            'Password' = $Password;
            'Query' = $createScript
        }

        # Create table on source database

        Invoke-Sqlcmd @params
       
        if (!$?) {

            Write-Host "SQL table creation failed in database $($params.Database). Please check the error and try again" -ForegroundColor Red
            break  

        }
        else {
             Write-Host "SQL table created in database $($params.Database)"  -ForegroundColor Green
        }

        # Insert records on source table

        $params.Query = $insertScript

        Invoke-Sqlcmd @params

        if (!$?) {

            Write-Host "SQL data insertion failed in database $($params.Database). Please check the error and try again" -ForegroundColor Red
            break  

        }
        else {
             Write-Host "SQL records inserted successfully in database $($params.Database)" -ForegroundColor Green
        }

        $ServerInstance = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.targetSqlServer.value -o tsv
        $DatabaseName = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.targetDB.value -o tsv
        $Username = az  deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sqlAdmin.value -o tsv

        $params = @{
            'ServerInstance' = $ServerInstance;
            'Database' = $DatabaseName;
            'Username' = $Username;
            'Password' = $Password;
            'Query' = $createScript
        }

        # Create table on target database

        Invoke-Sqlcmd @params
       
        if (!$?) {

            Write-Host "SQL table creation failed in database $($params.Database). Please check the error and try again" -ForegroundColor Red
            break  

        }
        else {
             Write-Host "SQL table created in database $($params.Database)"  -ForegroundColor Green
        }
     
    }

    
    function CreateBlobObject {
        Write-Host "Starting upload of Blob object" -ForegroundColor Yellow
        $BlobObject = Join-Path -Path (Get-Location) -ChildPath '\BlobObjects\FootballClubs.csv'

        $SourceStgAccName = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sourceStorageAccountName.value -o tsv
        $SourceBlobContainer = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.sourceBlobContainer.value -o tsv

        $ConnectionString = az storage account show-connection-string -g $RgName -n $SourceStgAccName --query connectionString -o tsv

        $ErrorMessage = $($Result = az storage blob upload --container-name $SourceBlobContainer --file $BlobObject --name 'FootballClubs.csv' --connection-string $ConnectionString) 2>&1

        if ($null -eq $Result) {

            Write-Host "Blob object upload failed.. Please check the details of the error below and try again." -ForegroundColor Red
            Write-Host $ErrorMessage -ForegroundColor Red
            break  

        }
        else {
             Write-Host "Blob object upload completed successfully" -ForegroundColor Green
        }

    }

    
    function SetStoragePermissions {
        Write-Host "Starting RBAC assignment" -ForegroundColor Yellow
        $ADFName = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.dataFactoryName.value -o tsv

        $ADFObjectId = az deployment group show -g $RgName --name 'demo-objects' --query properties.outputs.dataFactoryPrincipalId.value -o tsv

        $ErrorMessage = $($Result = az role assignment create --role 'Storage Blob Data Contributor' --assignee $ADFObjectId -g $RgName) 2>&1

        if ($null -eq $Result) {

            Write-Host "RBAC assignment failed.. Please check the details of the error below and try again." -ForegroundColor Red
            Write-Host $ErrorMessage -ForegroundColor Red
            break  

        }
        else {
             Write-Host "RBAC assignment completed successfully" -ForegroundColor Green
        }


    }

    CheckResourceGroup

    CreateDeployment

    CreateSQLObjects($SqlServerPassword)

    CreateBlobObject

    SetStoragePermissions



