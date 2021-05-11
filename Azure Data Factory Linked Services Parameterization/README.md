## PowerShell Script

The script *DeployAzureResources.ps1* will help you deploy the required resources to follow the blog post available [here](https://www.pedrofiadeiro.com/azure-data-factory-policies/azure-data-factory-linked-services-parameterization)

The following steps will be done by the script:
- 2 SQL Servers with a database each will be created. 
- Both will have firewall rules to allow Azure services to connect and your own ip address assuming you specify it correctly.
- On the source database, a table will be created and a few records inserted. On the target database, a table will be created with no records.
- 2 storage accounts, each with a container, will be created. A file will be uploaded to the source storage account
- A Data Factory Instance will be created. 2 linked services will also be added, one for Azure SQL Database and another for Data Lake Gen2
- Permissions will be assigned to the ADF instance to access both storage accounts

## Requirements

In order to run this script you need the PowerShell modules **Az** and **SqlServer**. If you don't have them installed you can do it by executing the instructions seen in the image below

![PowerShell Modules](Images/PowerShell_Modules.png)

You'll also need the Azure CLI which can be installed by following the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Execution

Before executing the script, in the file **azuredeploy.parameters.json**, the only parameter that needs to be changed is **clientIpValue** where you should input the ip address you're currently using. This is required in order to connect to the databases and create the objects.

You can change the value of the other parameters but it's not required. Most objects such as the SQL Server, ADF instance and storage accounts will use the parameter value and the resource group unique id to create an unique name. I suggest not altering the value of the other parameters.

To execute the PowerShell script just run

```PowerShell
.\DeployAzureResources.ps1 -SqlServerPassword 'YourVer1S3cur3Passw0rd' -RgName 'rg-name'
```

Take into account that the SQL Server Password  must be between 8 to 128 characters and include three of the following categories: English uppercase letters, English lowercase letters, numbers and non-alphanumeric characters. It cannot contain all or part of the login name.

After executing the script you'll have all objects required to follow the steps described in the blog post.