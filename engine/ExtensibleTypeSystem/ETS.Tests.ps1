Describe -tags 'Innerloop', 'DRT' "bug163162" {
#     Bug 987727: Export-CSV adding unwanted columns when pulling from sqlDataAdapter
	It "Default formatting of a string should contain the address in a human-readable form" {
        $s = [ipaddress]::parse("127.0.0.1") | out-string
		$s.Contains("127.0.0.1") | Should Be $true
	}
}
Describe -tags 'Innerloop', 'DRT' "bug196748" {
    # Bug 987727: Export-CSV adding unwanted columns when pulling from sqlDataAdapter
    It "actual properties should match expected properties" {
        $dataSet = new-object System.Data.DataSet
        $dataTable = new-object System.Data.DataTable
        $dataTable.Columns.add($(new-object system.data.datacolumn "column1"))
        $dataSet.Tables.add($dataTable)
        $table = $dataSet.Tables[0]

        $drow = $table.NewRow()
        $drow["column1"] = "abc"
        $table.Rows.add($drow)

        $csvFile =  "${TestDrive}\file.csv"
        $dataSet.tables[0] | export-csv $csvFile -encoding ascii -NoTypeInformation
        $expectedProperties = $dataset.tables[0] | get-member -MemberType properties -view extended,adapted | select-object name
        $actualProperties = import-csv $csvFile | get-member -MemberType properties | select-object name
    
        $compare = Compare-object $expectedProperties $ActualProperties
        $compare | Should BeNullOrEmpty
    }
}
Describe -tags 'Innerloop', 'DRT' "bug343566-UpdateTypeDataForDuplicateFiles" {
#      Win8: 343566 - Import module ServerManagerShell generate errors
#      We are fixing the loading of type files to be idempotent

	It "There should be no errors when loading a type file twice" {
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
        $iss.ThrowOnRunspaceOpenError = $true
        $ps = [System.Management.Automation.PowerShell]::Create($iss)
        $ps.AddCommand("Update-TypeData").AddArgument("$pshome\types.ps1xml").Invoke()
		$ps.Streams.Error.Count | Should Be 0
	}

	It "There should be no errors when loading a type file twice" {
        $rsconfig = [System.Management.Automation.Runspaces.RunspaceConfiguration]::Create()
        $rs  = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($rsconfig)
        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.Runspace = $rs
        $ps.Runspace.Open()
        $ps.AddCommand("Update-TypeData").AddArgument("$pshome\types.ps1xml").Invoke()
		$ps.Streams.Error.Count | Should Be 0
	}

}
Describe -tags 'Innerloop', 'DRT' "bug987727" {
    #     Bug 987727:Assigning value to static readonly field crashes powershell on downlevel,
    #     and make powershell not usable on Vista.
	It "There should be 1 exception while performing [string]::Empty='a'" {
        try {
            [string]::Empty = "a"
            Throw "Execution OK"
        }
        catch {
            $_.FullyQualifiedErrorId | Should be "PropertyAssignmentException"
        }
    }
}
Describe -tags 'Innerloop', 'DRT' "StaticMethodInfo" {
#     Bug 942937:Non-Static members return method info when a method name
#     is referenced as property. But static members return nothing.
	It "Retrieve Static method info using [System.IO.File]::Open is possible" {
        $methodInfo = [System.IO.File]::Open
		$methodInfo | Should Not BeNullOrEmpty
	}

}
Describe -tags 'Innerloop', 'DRT' "Test-TypeFormatLazyLoading" {
#     Validates that types and formatting load script blocks lazily.

    BeforeAll {
        ## Create a type file with bad info
        $typePath = "${TestDrive}\badInfo.Types.ps1xml"
        $badTypeData = '<?xml version="1.0" encoding="utf-8" ?>',
        '<Types>', '<Type>',
        '<Name>System.Array</Name>', '<Members>',
        '<ScriptProperty>', '<Name>ErrorProperty</Name>',
        '<GetScriptBlock>for some error in (invalid $syntax</GetScriptBlock>',
        '</ScriptProperty>', '</Members>',
        '</Type>', '</Types' 
        $BadTypeData | Set-Content $typePath 

        $formatPath = "${TestDrive}\badInfo.Format.ps1xml"
        $badFormatData = '<?xml version="1.0" encoding="utf-8" ?>',
        '<Configuration>', '<ViewDefinitions>', '<View>', '<Name>MatchInfo</Name>',
        '<ViewSelectedBy>', '<TypeName>Microsoft.PowerShell.Commands.MatchInfo</TypeName>', '</ViewSelectedBy>',
        '<CustomControl>', '<CustomEntries>', '<CustomEntry>', '<CustomItem>', '<ExpressionBinding>', '<ScriptBlock>for some error in (invalid $syntax</ScriptBlock>', '</ExpressionBinding>', '</CustomItem>',
        '</CustomEntry>', '</CustomEntries>', '</CustomControl>', '</View>', '</ViewDefinitions>', '</Configuration>'
        $badFormatData | Set-Content $formatPath 
    }

    Context "Test lazy loading of types in InitialSessionState" {

        BeforeAll {
            ## Verify that it is not parsed at startup
            $r = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
            $r.Types.Add($typePath)
            $rsDefault2 = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($r)
            $rsDefault2.Open()
        }
        AfterAll {
            $rsDefault2.Close()
        }

        It "Should have no error so far" {
            $rsDefault2.CreatePipeline('$error').Invoke()[0] | Should beNullOrEmpty
        }

        ## But that it is when you update the type data
        It "Updating type data should have generated an error" {
            $rsDefault2.CreatePipeline('Update-TypeData').Invoke()
            $le = $rsDefault2.CreatePipeline('$error').Invoke()[0]
            $le.FullyQualifiedErrorId | Should Be "TypesXmlUpdateException,Microsoft.PowerShell.Commands.UpdateTypeDataCommand" 
        }
    }

    Context "Test lazy loading of formats in InitialSessionState" {
        ## Can't do this, as V2 didn't report an error and therefore we can't.
        ## Test lazy load of types in RunspaceConfiguration
        ## Verify that it is not parsed at startup
        BeforeAll {
            $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rs.RunspaceConfiguration.Types.Append($typePath)
            $rs.Open()
        }
        AfterAll {
            $rs.Close()
        }
        It "Should have no error so far" {
            $rs.CreatePipeline('$error').Invoke()[0] | Should beNullOrEmpty
        }

        ## But that it is when you update the type data
        It "Updating type data should have generated an error" {
            $rs.CreatePipeline('Update-TypeData').Invoke()
            $le = $rs.CreatePipeline('$error').Invoke()[0]
            $le.FullyQualifiedErrorId | Should Be "TypesXmlUpdateException,Microsoft.PowerShell.Commands.UpdateTypeDataCommand" 
        }
    }

    Context "lazy load of formatting in RunspaceConfiguration" {
        BeforeAll {
            ## Verify that it is not parsed at startup
            $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rs.RunspaceConfiguration.Formats.Append($formatPath)
            $rs.Open()
        }
        AfterAll {
            $rs.Close()
        }
        It "Should have no error so far" {
            $rs.CreatePipeline('$error').Invoke() | Should BeNullOrEmpty
        }

        ## But that it is when you update the format data
        It "Updating type data should have generated an error" {
            [void] $rs.CreatePipeline('Update-FormatData').Invoke()
            $le = $rs.CreatePipeline('$error').Invoke()[0]
            $le.FullyQualifiedErrorId | Should Be "FormatXmlUpdateException,Microsoft.PowerShell.Commands.UpdateFormatDataCommand" 
        }
    }

}

Describe -tags 'Innerloop', 'P1' "win8_437544" {
#       Win8: 437544 XML type adapter should not project whitespace
BeforeAll {
$content = @"
<a>

<b/>

</a>
"@
$xml = [xml]$content
}
	It "Win8: 437568 Xml adapter does not project whitespaces" {
        $format = $xml | format-custom | out-string
		$format | Should Not Match "whitespace"
	}
}

#  Win8: 449892 - Regression [win7]: Update-TypeData gives lots of misleading 
# errors when the real cause is due to script execution being disabled.
Describe -tags 'Innerloop', 'DRT' "win8_449892" {
    BeforeAll {
        $oldExecutionPolicy = Get-ExecutionPolicy
        # Create standalone types file
        $newTypeData = '<Types><Type><Name>System.Array</Name>' +
            '<Members><ScriptProperty><Name>Hello</Name>' +
            '<GetScriptBlock>"hello"</GetScriptBlock>' +
            '</ScriptProperty></Members></Type></Types>' 
        $typesPath = "TestDrive:\bug449892.types.ps1xml"
        $newTypeData | Set-content $typesPath
            
    }
	It "The error is correct for not updating type file" {
        Set-ExecutionPolicy Restricted -force -scope process
        Update-TypeData -PrependPath $typesPath -errorVariable ev 2>&1
        Set-ExecutionPolicy $oldExecutionPolicy -force -scope process
        Remove-TypeData -path $typesPath
        $ev.fullyqualifiederrorid | Should be "TypesXmlUpdateException,Microsoft.PowerShell.Commands.UpdateTypeDataCommand"
	}
}

Describe -tags 'Innerloop', 'DRT' "win8_543106" {
    # Win8: 543106 [Win7 Regression]: PowerShell can no longer access parameterized properties
	It "Parameterized properties should be invokable" {
        $x = [xml]"<a>foo</a>"
        $actual = $x.item("a").innertext
		$actual | Should Be "foo"
	}
}

Describe -tags 'Innerloop', 'P1' "WinBlue_541173_RedirectAliasPropertyTo64bitVersion" {
    # WinBlue:541173 - Get-Process returns wrapped up process counters for hcs_dpmain
    # Redirect the alias properties VM, WS, PM and NPM to the 64-bit properties 'VirtualMemorySize64', 'WorkingSet64',
    # 'PagedMemorySize64' and 'NonpagedSystemMemorySize64'.

    BeforeAll {
        $process = Get-Process -Id $PID
    }
	It "VM should use the Int64 type property 'VirtualMemorySize64'" {
		$process.VM.GetType() | Should Be ([System.Int64])
	}
	It "WS should use the Int64 type property 'WorkingSet64'" {
		$process.WS.GetType() | Should Be ([System.Int64])
	}
	It "PM should use the Int64 type property 'PagedMemorySize64'" {
		$process.PM.GetType() | Should Be ([System.Int64])
	}
	It "NPM should use the Int64 type property 'NonpagedSystemMemorySize64'" {
		$process.NPM.GetType() | Should Be ([System.Int64])
	}
}

