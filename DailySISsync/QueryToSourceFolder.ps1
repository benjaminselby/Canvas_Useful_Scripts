

#####################################################################################################
# VARIABLES                                                                                         #
#####################################################################################################


# Initially I coded the dates to be automatic, but I think it's better that they remain manually 
# set so that we can roll forward only when we are ready. 
$Year       = 2020
$Semester   = 2

# Array which will contain all queries to be run for the export. 
$queries  = @()

# Formatted strings to display status of CSV exports. 
$exportNotificationHeader = @'
-------------------------
CSV                  ROWS
-------------------------
'@
$exportNotificationMessage = @'
{0,-15}{1,10:n0} 
'@
$exportNotificationFooter = @'
-------------------------
'@

# Folder which CSVs should be exported to. 
$output_folder = 'c:\Canvas\SIS_Upload\Source'


#####################################################################################################
# FUNCTIONS                                                                                         #
#####################################################################################################


Function Run-Query {

    param(
        [string[]] $queries,
        [string[]] $sheetnames)

    Begin {
        $SQLServer     = 'Synergy'
        $Database      = 'SynergyOne'
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $Database;User Id = SA; Password = 8Td52N55"
    } #End Begin

    Process {

        Write-Host "`n$exportNotificationHeader"

        # Loop through each query
        For($i = 0; $i -lt $queries.count; $i++)
        {
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            # Use the current index ($i) to get the query
            $SqlCmd.CommandText = $queries[$i]
            $SqlCmd.Connection = $SqlConnection

            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object System.Data.DataSet
            $SqlAdapter.Fill($DataSet) | Out-Null

            # Use the current index ($i) to get the sheetname for the CSV
            $DataSet.Tables[0] | Export-Csv -NoTypeInformation -Path "$output_folder\$($sheetnames[$i]).csv"            
            Write-Host ($exportNotificationMessage -f $sheetnames[$i], $DataSet.Tables[0].Rows.Count)            
        }

        Write-Host "$exportNotificationFooter`n"

    } # End Process

    End {
        $SqlConnection.Close()
    }

} # End function run-query.


#####################################################################################################
# USERS Query                                                                                       #
#####################################################################################################


$queries += @"

    /* Teachers enrolled in Synergy classes. */
    SELECT 
        UserId as user_id, 
        Email as login_id,
        '' as authentication_provider_id,
        '' as password,
        FirstName as first_name, 
        LastName as last_name, 
        PreferredName + ' ' + LastName as short_name, 
        Email as email, 
        UserStatus as status
    from woodcroft.utfCanvasEnrollments($Year, $Semester)

    union 

    /* TRT support teachers who may not be enrolled in Synergy classes. */ 
    select 
        STF.ID as user_id,
        COM.OccupEmail as login_id,
        '' as authentication_provider_id,
        '' as password,
        COM.Preferred as first_name, 
        COM.Surname as last_name, 
        COM.Preferred + ' ' + Com.Surname as short_name, 
        COM.OccupEmail as email, 
        'active' as status
    from Staff as STF
    left join Community as COM
        on STF.ID = COM.ID
    where STF.Category = 'TRT' 
        and STF.ActiveFlag = 1
        and COM.OccupEmail like '%@woodcroft.sa.edu.au'

"@


#####################################################################################################
# COURSES Query                                                                                     #
#####################################################################################################


$queries += @"
 
    select distinct 
        CanvasCourseId as course_id, 
        CASE 
            WHEN ClassCode like '10%ROT%' THEN ClassCode
            WHEN CanvasTerm IN ('FY_$Year', '2Y_$Year', '2Y_$($Year - 1)') THEN ClassDescription
            ELSE ClassDescription  + ' S$Semester'  
        END AS short_name,  
        CASE 
            WHEN CanvasTerm IN ('FY_$Year', '2Y_$Year', '2Y_$($Year - 1)') THEN ClassCode + ' ' + ClassDescription
            ELSE ClassCode + ' ' + ClassDescription  + ' Sem $Semester'
        END AS long_name,  
        CanvasTerm as term_id,
        'Active' as status
    from woodcroft.utfCanvasEnrollments($Year, $Semester)
    where ClassCode NOT like '11TOKIB%' 
        and ClassCode NOT in ('8CBHPD', '8DHHPD', '9DKHPD', '9ETHPD', '9SKHPD')
        and EnrollmentStatus <> 'Deleted'

"@


#####################################################################################################
# ENROLLMENTS Query                                                                                 #
#####################################################################################################


$queries += @"

    select distinct 
        CanvasCourseId as course_id, 
        UserId as user_id, 
        Role, 
        CourseSection as section_id,
        EnrollmentStatus as status
    from woodcroft.utfCanvasEnrollments($Year, $Semester)

"@


#####################################################################################################


$sheetnames = @()
$sheetnames += 'Users'
$sheetnames += 'Courses'
$sheetnames += 'Enrollments'

Run-Query -queries $queries -sheetnames $sheetnames
