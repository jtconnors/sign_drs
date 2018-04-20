#
# Powershell script to sign a Deployment Rule Set with either a self-signed
# certificate or a trusted certificate from a Certificate Authority.
#
# Invoke this script with the '-help' option for a brief description on
# how to run.
#

##################################################
#
# Variables Section: Important! Modifications may be required here,
# and definitely will be if signing with a trusted certificate.
#

#
# This variable MUST be set with a valid Java JDK location
#
Set-Variable -Name JDK_HOME -Value "C:\Program Files\Java\jdk1.8.0_172"

#
# If you want to sign the Deployment Rule Set with a trusted certificate
# these variables MUST be set with valid values.
#
Set-Variable -Name CA_CERT_KEYSTORE -Value "C:\MyKeystore.jks"
Set-Variable -Name CA_CERT_ALIAS -Value "My Alias"
Set-Variable -Name CA_CERT_KEYSTORE_PASSWD -Value "changeit"
Set-Variable -Name CA_CERT_TRUSTSTORE_PASSWD -Value "changeit"
# This variable is optional and must be set if using the '-timestamp' option
Set-Variable -Name CA_CERT_TIMESTAMP_AUTHORITY -Value "http://MyTimestampURL"

#
# These variables are used for self-signing the Deployment Rule Set.
# They can be left as is or customized to suit your needs.
#
Set-Variable -Name DN -Value "CN=Ruleset Signer, OU=jtconnors.com, O=Test, L=New York, ST=NY, C=US"
Set-Variable -Name SELF_SIGN_KEYSTORE -Value "keystore.jks"
Set-Variable -Name SELF_SIGN_ALIAS -Value "selfsign_drs"
Set-Variable -Name SELF_SIGN_KEYSTORE_PASSWD -Value "changeit"
Set-Variable -Name SELF_SIGN_TRUSTSTORE_PASSWD -Value "changeit"
Set-Variable -Name SELF_SIGN_CERT_FILE -Value "$SELF_SIGN_ALIAS.cer"

#
# These variables are best left as they are
# 
Set-Variable -Name SELF_SIGN_TRUSTSTORE -Value drscacerts
Set-Variable -Name SELF_SIGN_TIMESTAMP_AUTHORITY -Value "http://sha256timestamp.ws.symantec.com/sha256/timestamp"

#
# End Variables Section
#
##################################################

##################################################                              
#
# Helper Functions
#

#
# Print a command with all its args on one line. 
#
function Print-Cmd {
    Foreach ($item in $args[0]) {
       $CMD += $item
       $CMD += " "
    }
    Write-Output $CMD
}

#
# Execute a command, optionally print out that command and check exit status.
# If status is non-zero, exit
#
function Run-Cmd {
    Set-Variable -Name OPTIONS -Value @()
    $COMMAND = $($args[0][0])
    Foreach ($item in $args[0][1]) {
       $OPTIONS += $item
    }
    if ($VERBOSE -eq "true") {
        Print-Cmd ($COMMAND, $OPTIONS)
    }
    & $COMMAND $OPTIONS
    if ($LASTEXITCODE -ne 0) {
        Exit $LASTEXITCODE
    }
}

#
# Delete files produced from previous run if they exist
#
function Do-Clean {
    Foreach ($item in @("$SELF_SIGN_KEYSTORE",
                        "$SELF_SIGN_TRUSTSTORE",
                        "$SELF_SIGN_CERT_FILE",
                        "DeploymentRuleSet.jar",
                        "deployment.properties")) {
        if ((Test-Path $item)) {
            Remove-Item $item
        } 
    }
}

#
# End Helper functions
#
##################################################

##################################################
#
# Command-line argument processing
#
Set-Variable -Name SCRIPT_NAME -Value $MyInvocation.MyCommand.Name

function Print-Help {
    Write-Output "${SCRIPT_NAME}: Deployment RuleSet signing script"
    Write-Output ""
    Write-Output "One of the following options must be used:"
    Write-Output ""
    Write-Output " -help         Print this Message and exit"
    Write-Output " -clean        Delete generated files and exit"
    Write-Output " -selfsign     Sign Deployment Rule Set with self-signed certificate"
    Write-Output " -casign       Sign Deployment Rule Set with a trusted certificate from a CA"
    Write-Output ""
    Write-Output "The following arguments are optional:"
    Write-Output ""
    Write-Output " -timestamp    Sign with a timestamp"
    Write-Output " -jks          Use JKS keystore type instead of default PKCS12"
    Write-Output " -verbose      Output commands used to accomplish signing"
    Write-Output ""
}

Set-Variable -Name DO_SELF_SIGN -Value false
Set-Variable -Name DO_CA_SIGN -Value false
Set-Variable -Name USE_TIMESTAMP -Value false
Set-Variable -Name USE_JKS -Value false

if ($args.count -gt 0) {
    Foreach ($arg in $args) {
        switch ($arg) {
            '-help' { 
                Print-Help
                Exit 0
            }
            '-clean' { 
                Do-Clean
                Exit 0
            }
            '-selfsign' { 
                Set-Variable -Name DO_SELF_SIGN -Value true            
                Set-Variable -Name KEYSTORE -Value $SELF_SIGN_KEYSTORE
                Set-Variable -Name ALIAS -Value $SELF_SIGN_ALIAS
                Set-Variable -Name KEYSTORE_PASSWD -Value $SELF_SIGN_KEYSTORE_PASSWD
                Set-Variable -Name TRUSTSTORE_PASSWD -Value $SELF_SIGN_TRUSTSTORE_PASSWD
                Set-Variable -Name CERT_FILE -Value $SELF_SIGN_CERT_FILE
                Set-Variable -Name TRUSTSTORE -Value $SELF_SIGN_TRUSTSTORE
                Set-Variable -Name TIMESTAMP_AUTHORITY -Value $SELF_SIGN_TIMESTAMP_AUTHORITY
            }
            '-casign' { 
                Set-Variable -Name DO_CA_SIGN -Value true
                Set-Variable -Name KEYSTORE -Value $CA_CERT_KEYSTORE
                Set-Variable -Name ALIAS -Value $CA_CERT_ALIAS
                Set-Variable -Name KEYSTORE_PASSWD -Value $CA_CERT_KEYSTORE_PASSWD
                Set-Variable -Name TRUSTSTORE_PASSWD -Value $CA_CERT_TRUSTSTORE_PASSWD
                Set-Variable -Name TIMESTAMP_AUTHORITY -Value $CA_CERT_TIMESTAMP_AUTHORITY
            }
            '-timestamp' { Set-Variable -Name USE_TIMESTAMP -Value true }
            '-jks' { Set-Variable -Name USE_JKS -Value true }
            '-verbose' { Set-Variable -Name VERBOSE -Value true }
            default {
                Write-Output "`nUnknown option: ""$arg""`n"
                Print-Help
                Exit 1               
            }
        } 
    }
} else {
    Print-Help
    Exit 1
}

if ($DO_SELF_SIGN -eq "false" -and $DO_CA_SIGN -eq "false") {
    Print-Help
    Exit 0
}
#
# End command-line argument processing
#
##################################################

#
# Make sure all files/directories in the following list can be accessed
# 
Foreach ($item in @("$JDK_HOME",
                     "$JDK_HOME\bin\keytool.exe",
                     "$JDK_HOME\bin\jar.exe",
                     "$JDK_HOME\bin\jarsigner.exe",
                     'ruleset.xml')) {
    if (!(Test-Path $item)) {
        Write-Error -Message "Cannot Access $item"
        Exit -1
    } 
}

#
# Delete files produced from previous run if they exist
#
Do-Clean

#
# Step 1: If using a self-signed certificate, generate the self-signed
# certificate
#
if ($DO_SELF_SIGN -eq "true") {
    #
    # Step 1, part a: generate a key pair that will be used as the 
    # "Cerificate Authority"
    #
    Set-Variable -Name GEN_KEYPAIR_CMD_ARGS -Value @(
        '-genkey',
        '-keyalg',
        'RSA',
        '-alias',
        """$ALIAS""",
        '-keystore',
        """$KEYSTORE""",
        '-dname',
        """$DN""",
        '-storepass',
        """$TRUSTSTORE_PASSWD""",
        '-keypass',
        """$KEYSTORE_PASSWD""",
        '-validity',
        '730',
        '-keysize',
        '2048',
        '-storetype'
        )
    if ($USE_JKS -eq "false") {
        $GEN_KEYPAIR_CMD_ARGS += 'pkcs12'
    } else {
        $GEN_KEYPAIR_CMD_ARGS += 'jks'
    }
    Write-Output "`n*** Generating key pair in ""$KEYSTORE"" with alias ""$ALIAS""`n"   
    Run-Cmd("$JDK_HOME\bin\keytool.exe", $GEN_KEYPAIR_CMD_ARGS)

    #
    # Step 1, part b: Export the signing certificate that was generated in
    # the previous step
    #
    Set-Variable -Name EXPORT_CMD_ARGS -Value @(
        '-export',
        '-keystore',
        """$KEYSTORE""",
        '-storepass',
        """$KEYSTORE_PASSWD""",
        '-file',
        """$CERT_FILE""",
        '-alias',
        """$ALIAS"""
        )
    Write-Output "*** Exporting Certificate from ""$KEYSTORE"" to ""$CERT_FILE""`n"
    Run-Cmd("$JDK_HOME\bin\keytool.exe", $EXPORT_CMD_ARGS)

    #
    # Step 1, part c: Import the signing certificate into the "drscacerts"
    # truststore.
    #
    Set-Variable -Name IMPORT_CMD_ARGS -Value @(
        '-import',
        '-noprompt',
        '-keystore',
        """$TRUSTSTORE""",
        '-storepass',
        """$TRUSTSTORE_PASSWD""",
        '-file',
        """$CERT_FILE""",
        '-alias',
        """$ALIAS"""
        )
    Write-Output "`n*** Importing Certificate from ""$CERT_FILE"" into ""$TRUSTSTORE""`n"
    Run-Cmd("$JDK_HOME\bin\keytool.exe", $IMPORT_CMD_ARGS)
}

#
# Step 2: Create the DeploymnentRuleSet.jar file
#
Set-Variable -Name JAR_ARGS -Value @(
    'cvf',
    'DeploymentRuleSet.jar',
    'ruleset.xml'
)
Write-Output "`n*** Creating DeploymentRuleSet.jar with ruleset.xml`n"
Run-Cmd("$JDK_HOME\bin\jar.exe", $JAR_ARGS)

#
# Step 3: Sign the DeploymentRuleSet.jar file.
#
Set-Variable -Name JARSIGNER_ARGS -Value @(
    '-keystore',
    """$KEYSTORE""",
    '-storepass',
    """$TRUSTSTORE_PASSWD""",
    '-keypass',
    """$KEYSTORE_PASSWD"""
)
if ($USE_TIMESTAMP -eq "true") {
    $JARSIGNER_ARGS += '-tsa'
    $JARSIGNER_ARGS += "$TIMESTAMP_AUTHORITY"
    Write-Output "`n*** Signing DeploymentRuleSet.jar with timestamp authority $TIMESTAMP_AUTHORITY`n"
} else {
    Write-Output "`n*** Signing DeploymentRuleSet.jar without timestamp`n"
}
$JARSIGNER_ARGS += 'DeploymentRuleSet.jar'
$JARSIGNER_ARGS += """$ALIAS"""

Run-Cmd("$JDK_HOME\bin\jarsigner.exe", $JARSIGNER_ARGS)

#
# Step 4: If using a self-signed certificate, create the deployment.properties file
#
if ($DO_SELF_SIGN -eq "true") {
    Write-Output "`n*** Creating the deployment.properties file"
    $DATE = Get-Date
    Add-content -Path deployment.properties -Value "# Created on $DATE"
    Add-Content -Path deployment.properties "deployment.user.security.trusted.cacerts=C\:\\Windows\\Sun\\Java\\Deployment\\$TRUSTSTORE"
}

#
# Output a message stating that the process is complete, which files were created and where
# those file(s) have to be placed to enable the Deployment Rule Set functionality.
#
if ($DO_SELF_SIGN -eq "true") {
    $GENERATED_FILES = "deployment.properties DeploymentRuleSet.jar drscacerts"
} else {
    $GENERATED_FILES = "DeploymentRuleSet.jar"
}
Write-Output "`n*** Signing complete."
Write-Output ""
Write-Output "In order to enable Deployment Rule Sets on your system, copy"
Write-Output "the following file(s):"
Write-Output ""
Write-Output "    $GENERATED_FILES"
Write-Output ""
Write-Output "to the C:\Windows\Sun\Java\Deployment\ directory"
Write-Output ""
Exit 0
