function ConvertTo-Datum
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject,

        [AllowNull()]
        $DatumHandlers = @{}
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        # if There's a matching filter, process associated command and return result
        if($HandlerNames = [string[]]$DatumHandlers.Keys) {
            foreach ($Handler in $HandlerNames) {
                $FilterModule,$FilterName = $Handler -split '::'
                if(!(Get-Module $FilterModule)) {
                    Import-Module $FilterModule -force -ErrorAction Stop
                }
                $FilterCommand = Get-Command -ErrorAction SilentlyContinue ("{0}\Test-{1}Filter" -f $FilterModule,$FilterName)
                if($FilterCommand -and ($InputObject | &$FilterCommand)) {
                    if($ActionCommand = Get-Command -ErrorAction SilentlyContinue ("{0}\Invoke-{1}Action" -f $FilterModule,$FilterName)) {
                        return (&$ActionCommand)
                    }
                }
            }
        }

        if ($InputObject -is [System.Collections.Hashtable] -or ($InputObject -is [System.Collections.Specialized.OrderedDictionary])) {
            $hashKeys = [string[]]$InputObject.Keys
            foreach ($Key in $hashKeys) {
                $InputObject[$Key] = ConvertTo-Datum -InputObject $InputObject[$Key] -DatumHandlers $DatumHandlers
            }
            $InputObject
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertTo-Datum -InputObject $object -DatumHandlers $DatumHandlers }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = [ordered]@{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertTo-Datum -InputObject $property.Value -DatumHandlers $DatumHandlers
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}