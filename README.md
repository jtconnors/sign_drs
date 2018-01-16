# sign_drs
Powershell script to facilitate signing Deployment Rule Sets with either a
self-signed or trusted certificate


## OVERVIEW

Java SE Advanced Support customers can download and use security
updates to older versions of Java that are not publicly available.  However,
as of the October 2017 patch update release for Java 6 (6u171) and 7 (7u161),
the Java plugin, necessary to run Java applets and WebStart applications, is
no longer provided.  In order for customer's web based (applets and WebStart)
applications to run with these latest versions, they need to configure
Deployment Rule Sets.  More information about Deployment Rule Sets can be found
here:

https://docs.oracle.com/javase/8/docs/technotes/guides/deploy/deployment_rules.html

Describing Rule Sets in detail is beyond the scope of this README, suffice it
to say, in order to correctly Deploy a rule set, the following high-level
setps must take place:

1. Create rules (in XML syntax) and store them in a file called ```ruleset.xml```
2. Using the ```jar(1)``` utility, create a ```DeploymentRuleSet.jar``` file that
   includes the ```ruleset.xml``` file
3. Sign the ```DeploymentRuleSet.jar``` file with a code-signing certificate
4. Place the signed ```DeploymentRuleSet.jar``` in the following Windows directory:
   ```C:\Windows\Sun\Java\Deployment\```
   
All four steps must be successfully completed.  Failure of any type in the
aforementioned sequence will result in an invalid Deployment Rule Set.

This project deals specifically with steps 2 and 3, namely the process of
creating and signing the ```DeploymentRuleSet.jar``` file.

The powershell script contained in this repository facilitates signing the
```DeploymentRuleSet.jar``` file -- a process considered by some to be both 
mysterious and challenging.  It can be directed to sign the Rule Set with
a trusted certificate  (definitely the preferred safer method), or for those
without access to a trusted certificate, with a self-signed variety that is
created on the fly.


## BEFORE RUNNING

The ```drs-sign-ruleset.ps1``` script contains a variable called ```JDK_HOME``` that
is set to the latest Java 8 update (as of the latest mod of this document,
16-January-2018, it is Java 8 update 162). Its assignment appears near
the top of the script and looks like this:  

   ```
   Set-Variable -Name JDK_HOME -Value "C:\Program Files\Java\jdk1.8.0_162"
   ```

You must either install JDK 8 update 162 in the same directory assigned above
or modify the ```JDK_HOME``` variable to match your installation environment.
Because JDK 8 update 162 changes some of its default behavior compared to
previous updates, no earlier release should be used.  As newer updates to the
JDK appear, they should be definitely used instead.


## TRYING IT OUT

After verifying that a proper ```JDK_HOME``` value has been supplied in the
```drs-sign-ruleset.ps1``` script, it should be straightforward to create a
sample self-signed rule set.  Issue the following commands from a
DOS CMD prompt in the directory containing both this ```README.md``` file
and the ```drs-sign-ruleset.ps1``` script:

   ```
   copy sample-ruleset.xml ruleset.xml  
   powershell .\drs-sign-ruleset.ps1 -selfsign
   ```
   
The resulting run will produce three files:

   ```
   DeploymentRuleSet.jar  
   drscacerts  
   deployment.properties
   ```

Once they are copied to the ```C:\Windows\Sun\Java\Deployment\``` directory,
(you'll need Administrator privieges to do so), a Deployment Rule Set will
be active.


## SIGNING WITH A TRUSTED CERTIFICATE FROM A CERTITICATE AUTHORITY

For those utilizing Deployment Rule Sets in production, it is STRONGLY
RECOMMENDED that the ```DeploymentRuleSet.jar``` file be signed with a certificate
from a trusted authority.  Beacuse it would be impossible to determine
beforehand the specifics of your trusted certificate, some customization of
the ```drs-sign-ruleset.ps1``` file is required.  Near the beginning of the script
there is a small section dedicated to setting the properties necessary to
use your signing certificate.  It appears as follows:

  ```
  Set-Variable -Name CA_CERT_KEYSTORE -Value "C:\MyKeystore.jks"  
  Set-Variable -Name CA_CERT_ALIAS -Value "My Alias"  
  Set-Variable -Name CA_CERT_KEYSTORE_PASSWD -Value "changeit"  
  Set-Variable -Name CA_CERT_TRUSTSTORE_PASSWD -Value "changeit"  
  Set-Variable -Name CA_CERT_TIMESTAMP_AUTHORITY -Value "http://MyTimestampURL"  
  ```
  
#### Here's a brief description of the 4 (or 5 if you want to timestamp) powershell variables that must be set:  

  ```$CA_CERT_KEYSTORE``` - This is the name of the file containing the encrypted 
     private and public keys of your signing certificate  

  ```$CA_CERT_ALIAS``` - Certificates are assigned an alias -- a string -- which is
     a more human readable way of uniquely identifying this entry in
     the keystore  
 
  ```$CA_CERT_KEYSTORE_PASSSWD```  
  ```$CA_CERT_TRUSTSTORE_PASSWD``` - Keystores are assigned passwords required
     to access respectively the keystore (containing private keys) and the
     truststore (containing the public certificates).  In many cases these
     two passwords are one in the same.  

  ```$CA_CERT_TIMESTAMP_AUTHORITY``` - This setting is required if you want to
     timestamp your signed Deployment Rule Set.  It can be initiated by 
     running the script with the '-timestamp' option.  The timestamp
     authority is a URL that that is typically provided by the Vendor
     responsible for issuing the trusted certificate.  

Other than the far better security implications, a signed Deployment Rule Set
from a trusted authority only needs to place the signed ```DeploymentRuleSet.jar```
file in the ```C:\Windows\Sun\Java\Deployment\``` directory.  The additional
```deployment.properties``` and ```drscacerts``` files, required for self-signed
certificates, are not needed, and should not exist.  


## COMMAND-LINE OPTIONS

A number of command-line arguments, a certain set of which are mandatory,
are available for running the ```drs-sign-ruleset.ps1``` script. A brief description
of the options follows.

#### One of the following options must be selected.  Failure to do so will result in the termination of the program with a non-zero exit status:

  ```-selfsign```  Sign the Deployment Rule Set with a generated self-signed
             certificate.  When complete, three files will be created:
             (1) ```DeploymentRuleSet.jar```, (2) ```deployment.properties``` and
             (3) ```drscaccerts```.  All three files must be placed, unmodified,
             in the ```C:\Windows\Sun\Java\Deployment\``` directory to enable
             the Java plugin to use the Deployment Rule Set feature.  

  ```-casign```    Sign the Deployment Rule Set with a trusted certificate from a
             certificate authority.  When complete, only one file will be
             created: ```DeploymentRuleSet.jar```.  It must be placed, unmodified,
             in the ```C:\Windows\Sun\Java\Deployment\``` directory to enable
             the Java plugin to use the Deployment Rule Set feature.  

  ```-help```      Prints a help screen briefly describing the command-line
             options then exits.  

  ```-clean```     Deletes all files generated by this script and returns the
             directory to its original state.  Upon completion, exit.  

#### The following arguments can be optionally be placed on the command-line

  ```-timestamp``` Timestamping a signed application enables it to remain vaild
             even after its certificate has expired.  Use this option if
             you know the timestamp URL location of your vendor (one is
             already provided for self-signed certificates) and you want to
             timestamp your signed rule set.  

  ```-jks```       Recently the default keystore for the Java ```keytool(1)``` utility
             has transitioned to the more modern, less proprietary PKCS12
             format.  If you wish to generate the keystore and trustsore in
             legacy JKS format, use this option.  

  ```-verbose```   Signing a rule set is composed of multiple steps.  Using this
             option will output each individual command, with arguments, that
             is executed along the way.  
